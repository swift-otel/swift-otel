//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2024 Moritz Lang and the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import Logging
@_spi(Logging) import OTel
import OTelTesting
import XCTest

final class OTelBatchLogProcessorTests: XCTestCase {
    private let resource = OTelResource(attributes: ["service.name": "log_batch_processor_tests"])

    func testBatchLogProcessorAccumulatesUntilQueueSize() async throws {
        let exporter = OTelInMemoryLogRecordExporter()
        let batchProcessor = OTelBatchLogRecordProcessor(
            exporter: exporter,
            configuration: OTelBatchLogRecordProcessorConfiguration(
                environment: .detected(),
                maximumQueueSize: 5,
                scheduleDelay: .seconds(60) // Should never trigger
            )
        )

        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask(operation: batchProcessor.run)

            let logHandler = OTelLogHandler(processor: batchProcessor, logLevel: .debug, resource: resource)
            let logger = Logger(label: "Test", logHandler)

            for i in 1...4 {
                logger.info("\(i)")
            }

            // Records are emitted asynchronously, so checking this without delay
            // is not representative
            try await Task.sleep(for: .milliseconds(1))
            XCTAssertEqual(exporter.records, [])

            logger.info("5")

            // Records are emitted asynchronously, so let's wait for that to happen
            try await Task.sleep(for: .milliseconds(1))
            XCTAssertEqual(exporter.records.count, 5)

            taskGroup.cancelAll()
        }
    }

    func testBatchLogProcessorEmitsEarlyAfterDelay() async throws {
        let exporter = OTelInMemoryLogRecordExporter()
        let batchProcessor = OTelBatchLogRecordProcessor(
            exporter: exporter,
            configuration: OTelBatchLogRecordProcessorConfiguration(
                environment: .detected(),
                maximumQueueSize: 100,
                scheduleDelay: .milliseconds(10)
            )
        )

        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask(operation: batchProcessor.run)

            let logHandler = OTelLogHandler(
                processor: batchProcessor,
                logLevel: .debug,
                resource: resource
            )
            let logger = Logger(label: "Test", logHandler)

            for i in 1...4 {
                logger.info("\(i)")
            }

            // Records are emitted asynchronously, so checking this without delay
            // is not representative
            try await Task.sleep(for: .milliseconds(1))
            XCTAssertEqual(exporter.records, [])

            // Records should update after delay
            try await Task.sleep(for: .milliseconds(11))
            XCTAssertEqual(exporter.records.count, 4)

            taskGroup.cancelAll()
        }
    }

    func testBatchLogProcessorForceFlushEmitsEarly() async throws {
        let exporter = OTelInMemoryLogRecordExporter()
        let batchProcessor = OTelBatchLogRecordProcessor(
            exporter: exporter,
            configuration: OTelBatchLogRecordProcessorConfiguration(
                environment: .detected(),
                maximumQueueSize: 5,
                scheduleDelay: .seconds(60) // Should never trigger
            )
        )

        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask(operation: batchProcessor.run)

            let logHandler = OTelLogHandler(
                processor: batchProcessor,
                logLevel: .debug,
                resource: resource
            )
            let logger = Logger(label: "Test", logHandler)

            for i in 1...4 {
                logger.info("\(i)")
            }

            try await Task.sleep(for: .milliseconds(1))
            XCTAssertEqual(exporter.records, [])

            try await batchProcessor.forceFlush()
            XCTAssertEqual(exporter.records.count, 4)

            taskGroup.cancelAll()
        }
    }

    func testBatchLogProcessorCancelsSlowExports() async throws {
        let exporter = OTelSlowLogRecordExporter(delay: .milliseconds(50))
        let batchProcessor = OTelBatchLogRecordProcessor(
            exporter: exporter,
            configuration: OTelBatchLogRecordProcessorConfiguration(
                environment: .detected(),
                maximumQueueSize: 5,
                scheduleDelay: .seconds(60), // Should never trigger
                exportTimeout: .milliseconds(10)
            )
        )

        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask(operation: batchProcessor.run)

            let logHandler = OTelLogHandler(
                processor: batchProcessor,
                logLevel: .debug,
                resource: resource
            )
            let logger = Logger(label: "Test", logHandler)

            for i in 1...5 {
                logger.info("\(i)")
            }

            try await batchProcessor.forceFlush()

            // Receiving Cancellation can take a small while
            try await Task.sleep(for: .milliseconds(1))

            XCTAssertEqual(exporter.records, [])
            XCTAssertEqual(exporter.cancelCount, 1)

            taskGroup.cancelAll()
        }
    }
}

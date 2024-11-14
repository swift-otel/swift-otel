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
@_spi(Logging) @_spi(Testing) import OTel
import OTelTesting
import XCTest

final class OTelBatchLogRecordProcessorTests: XCTestCase {
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

        await withThrowingTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask(operation: batchProcessor.run)

            let logHandler = OTelLogHandler(processor: batchProcessor, logLevel: .debug, resource: resource)
            var exportIterator = exporter.didExportBatch.makeAsyncIterator()
            let logger = Logger(label: "Test", logHandler)

            for i in 1...4 {
                logger.info("\(i)")
            }

            // TODO: Records are emitted asynchronously, so checking this without delay
            // is not representative
            XCTAssertEqual(exporter.records, [])

            logger.info("5")

            // Records are emitted asynchronously, so let's wait for that to happen
            await exportIterator.next()
            XCTAssertEqual(exporter.records.count, 5)

            taskGroup.cancelAll()
        }
    }

    func testBatchLogProcessorEmitsEarlyAfterDelay() async throws {
        let exporter = OTelInMemoryLogRecordExporter()
        let clock = TestClock()
        var sleeps = clock.sleepCalls.makeAsyncIterator()
        let batchProcessor = OTelBatchLogRecordProcessor(
            exporter: exporter,
            configuration: OTelBatchLogRecordProcessorConfiguration(
                environment: .detected(),
                maximumQueueSize: 100,
                scheduleDelay: .milliseconds(10)
            ),
            clock: clock
        )

        await withThrowingTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask(operation: batchProcessor.run)
            var iterator = exporter.didExportBatch.makeAsyncIterator()

            let logHandler = OTelLogHandler(
                processor: batchProcessor,
                logLevel: .debug,
                resource: resource
            )
            let logger = Logger(label: "Test", logHandler)

            for i in 1...4 {
                logger.info("\(i)")
            }

            // TODO: Records are emitted asynchronously, so checking this without delay
            // is not representative
            XCTAssertEqual(exporter.records.count, 0)

            await sleeps.next()
            clock.advance(by: .milliseconds(10))
            await sleeps.next()

            // Records should update after delay
            await iterator.next()
            XCTAssertEqual(exporter.records.count, 4)

            taskGroup.cancelAll()
        }
    }

    func testBatchLogProcessorForceFlushEmitsEarly() async throws {
        let exporter = OTelInMemoryLogRecordExporter()
        let clock = TestClock()
        var sleeps = clock.sleepCalls.makeAsyncIterator()
        let batchProcessor = OTelBatchLogRecordProcessor(
            exporter: exporter,
            configuration: OTelBatchLogRecordProcessorConfiguration(
                environment: .detected(),
                maximumQueueSize: 5,
                scheduleDelay: .seconds(60) // Should never trigger
            ),
            clock: clock
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

            await sleeps.next()

            // TODO: Records are emitted asynchronously, so checking this without delay
            // is not representative
            XCTAssertEqual(exporter.records.count, 0)

            try await batchProcessor.forceFlush()
            XCTAssertEqual(exporter.records.count, 4)

            taskGroup.cancelAll()
        }
    }

    func testBatchLogProcessorCancelsSlowExports() async throws {
        let clock = TestClock()
        var sleeps = clock.sleepCalls.makeAsyncIterator()
        let exporter = OTelSlowLogRecordExporter(delay: .milliseconds(50), clock: clock)
        let batchProcessor = OTelBatchLogRecordProcessor(
            exporter: exporter,
            configuration: OTelBatchLogRecordProcessorConfiguration(
                environment: .detected(),
                maximumQueueSize: 5,
                scheduleDelay: .seconds(60), // Should never trigger
                exportTimeout: .milliseconds(10)
            ),
            clock: clock
        )

        await withThrowingTaskGroup(of: Void.self) { taskGroup in
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

            await withThrowingTaskGroup(of: Void.self) { taskGroup in
                taskGroup.addTask {
                    try await batchProcessor.forceFlush()
                }

                await sleeps.next()
                clock.advance(by: .milliseconds(10))
            }

            XCTAssertEqual(exporter.records, [])
            XCTAssertEqual(exporter.cancelCount, 1)

            taskGroup.cancelAll()
        }
    }
}

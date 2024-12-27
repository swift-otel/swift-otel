//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2024 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import Logging
@_spi(Logging) import OTel
@_spi(Logging) import OTelTesting
import XCTest
import ServiceLifecycle

final class OTelMultiplexLogRecordProcessorTests: XCTestCase {
    private let resource = OTelResource(attributes: ["service.name": "log_simple_processor_tests"])

    func test_emit_emitsToAllProcessors() async throws {
        let exporter1 = OTelInMemoryLogRecordExporter()
        let simpleProcessor1 = OTelSimpleLogRecordProcessor(exporter: exporter1)

        let exporter2 = OTelInMemoryLogRecordExporter()
        let simpleProcessor2 = OTelSimpleLogRecordProcessor(exporter: exporter2)

        let processor = OTelMultiplexLogRecordProcessor(processors: [
            simpleProcessor1,
            simpleProcessor2,
        ])

        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask(operation: processor.run)

            let logHandler = OTelLogHandler(processor: processor, logLevel: .debug, resource: resource)
            let logger = Logger(label: "Test", logHandler)

            for i in 1 ... 4 {
                logger.info("\(i)")

                // Records are emitted asynchronously, so checking this without delay
                // is not representative
                try await Task.sleep(for: .milliseconds(100))

                var batchCount = await exporter1.exportedBatches.count
                XCTAssertEqual(batchCount, i)

                batchCount = await exporter2.exportedBatches.count
                XCTAssertEqual(batchCount, i)
            }

            taskGroup.cancelAll()
        }
    }

    func test_forceFlush_forceFlushesAllProcessors() async throws {
        let processor1 = OTelInMemoryLogRecordProcessor()
        let processor2 = OTelInMemoryLogRecordProcessor()
        let processor = OTelMultiplexLogRecordProcessor(processors: [processor1, processor2])

        try await processor.forceFlush()

        let processor1ForceFlushCount = await processor1.numberOfForceFlushes
        XCTAssertEqual(processor1ForceFlushCount, 1)

        let processor2ForceFlushCount = await processor2.numberOfForceFlushes
        XCTAssertEqual(processor2ForceFlushCount, 1)
    }

    func test_shutdown_shutsDownAllProcessors() async throws {
        let processor1 = OTelInMemoryLogRecordProcessor()
        let processor2 = OTelInMemoryLogRecordProcessor()
        let processor = OTelMultiplexLogRecordProcessor(processors: [processor1, processor2])

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))

        let startExpectation = expectation(description: "Expected task to start executing.")
        let finishExpectation = expectation(description: "Expected processor to finish shutting down.")
        Task {
            startExpectation.fulfill()
            try await serviceGroup.run()
            finishExpectation.fulfill()
        }

        await fulfillment(of: [startExpectation], timeout: 0.1)
        await serviceGroup.triggerGracefulShutdown()
        await fulfillment(of: [finishExpectation], timeout: 0.1)

        let processor1ShutdownCount = await processor1.numberOfShutdowns
        XCTAssertEqual(processor1ShutdownCount, 1)

        let processor2ShutdownCount = await processor2.numberOfShutdowns
        XCTAssertEqual(processor2ShutdownCount, 1)
    }
}

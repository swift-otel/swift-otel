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
import ServiceLifecycle
import XCTest

final class OTelMultiplexLogRecordProcessorTests: XCTestCase {
    func test_emit_emitsToAllProcessors() async throws {
        let exporter1 = OTelStreamingLogRecordExporter()
        let simpleProcessor1 = OTelSimpleLogRecordProcessor(exporter: exporter1)

        let exporter2 = OTelStreamingLogRecordExporter()
        let simpleProcessor2 = OTelSimpleLogRecordProcessor(exporter: exporter2)

        let processor = OTelMultiplexLogRecordProcessor(processors: [
            simpleProcessor1,
            simpleProcessor2,
        ])

        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask(operation: processor.run)

            var record = OTelLogRecord.stub(body: "test")
            processor.onEmit(&record)

            try await processor.forceFlush()

            var exporter1Iterator = await exporter1.batches.makeAsyncIterator()
            let exporter1Batch = await exporter1Iterator.next()
            XCTAssertEqual(try XCTUnwrap(exporter1Batch).map(\.body), ["test"])

            var exporter2Iterator = await exporter2.batches.makeAsyncIterator()
            let exporter2Batch = await exporter2Iterator.next()
            XCTAssertEqual(try XCTUnwrap(exporter2Batch).map(\.body), ["test"])

            taskGroup.cancelAll()
        }
    }

    func test_forceFlush_forceFlushesAllProcessors() async throws {
        let processor1 = OTelInMemoryLogRecordProcessor()
        let processor2 = OTelInMemoryLogRecordProcessor()
        let processor = OTelMultiplexLogRecordProcessor(processors: [processor1, processor2])

        try await processor.forceFlush()

        let processor1ForceFlushCount = processor1.numberOfForceFlushes
        XCTAssertEqual(processor1ForceFlushCount, 1)

        let processor2ForceFlushCount = processor2.numberOfForceFlushes
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

        let processor1ShutdownCount = processor1.numberOfShutdowns
        XCTAssertEqual(processor1ShutdownCount, 1)

        let processor2ShutdownCount = processor2.numberOfShutdowns
        XCTAssertEqual(processor2ShutdownCount, 1)
    }
}

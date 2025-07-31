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

import Logging
import OTelCore
import OTelTesting
import ServiceLifecycle
import XCTest

final class OTelMultiplexSpanProcessorTests: XCTestCase {
    func test_onStart_forwardsStartedSpanToAllProcessors() async {
        let processor1 = OTelInMemorySpanProcessor()
        let processor2 = OTelInMemorySpanProcessor()
        let processor = OTelMultiplexSpanProcessor(processors: [processor1, processor2])

        let span = OTelSpan.recordingStub(operationName: "test")

        await processor.onStart(span, parentContext: .topLevel)

        let processor1StartedSpans = await processor1.startedSpans
        XCTAssertEqual(processor1StartedSpans.map(\.0.operationName), ["test"])

        let processor2StartedSpans = await processor2.startedSpans
        XCTAssertEqual(processor2StartedSpans.map(\.0.operationName), ["test"])
    }

    func test_onEnd_forwardsFinishedSpanToAllProcessors() async {
        let processor1 = OTelInMemorySpanProcessor()
        let processor2 = OTelInMemorySpanProcessor()
        let processor = OTelMultiplexSpanProcessor(processors: [processor1, processor2])

        let span = OTelFinishedSpan.stub(operationName: "test")

        await processor.onEnd(span)

        let processor1FinishedSpans = await processor1.finishedSpans
        XCTAssertEqual(processor1FinishedSpans.map(\.operationName), ["test"])

        let processor2FinishedSpans = await processor2.finishedSpans
        XCTAssertEqual(processor2FinishedSpans.map(\.operationName), ["test"])
    }

    func test_forceFlush_forceFlushesAllProcessors() async throws {
        let processor1 = OTelInMemorySpanProcessor()
        let processor2 = OTelInMemorySpanProcessor()
        let processor = OTelMultiplexSpanProcessor(processors: [processor1, processor2])

        try await processor.forceFlush()

        let processor1ForceFlushCount = await processor1.numberOfForceFlushes
        XCTAssertEqual(processor1ForceFlushCount, 1)

        let processor2ForceFlushCount = await processor2.numberOfForceFlushes
        XCTAssertEqual(processor2ForceFlushCount, 1)
    }

    func test_shutdown_shutsDownAllProcessors() async throws {
        LoggingSystem.bootstrapInternal(logLevel: .trace)
        let processor1 = OTelInMemorySpanProcessor()
        let processor2 = OTelInMemorySpanProcessor()
        let processor = OTelMultiplexSpanProcessor(processors: [processor1, processor2])

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

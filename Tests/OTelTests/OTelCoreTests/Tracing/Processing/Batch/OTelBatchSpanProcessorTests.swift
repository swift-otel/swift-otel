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
@testable import OTel
import ServiceLifecycle
import XCTest

final class OTelBatchSpanProcessorTests: XCTestCase {
    func test_onEnd_whenTicking_exportsNextBatch() async throws {
        LoggingSystem.bootstrapInternal(logLevel: .trace)

        let exporter = OTelStreamingSpanExporter()
        let clock = TestClock()
        var sleeps = clock.sleepCalls.makeAsyncIterator()
        let processor = OTelBatchSpanProcessor(
            exporter: exporter,
            configuration: .init(environment: [:], scheduleDelay: .seconds(2)),
            clock: clock
        )

        let span1 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "1")
        let span2 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "2")
        let span3 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "3")

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))
        Task {
            try await serviceGroup.run()
        }

        await processor.onEnd(span1)
        await processor.onEnd(span2)
        await processor.onEnd(span3)

        // await first sleep for "tick"
        await sleeps.next()
        clock.advance(by: .seconds(2))

        var batches = exporter.batches.makeAsyncIterator()
        let batch = await batches.next()
        XCTAssertEqual(try XCTUnwrap(batch).map(\.operationName), ["1", "2", "3"])
    }

    func test_onEnd_withUnsampledSpan_whenTicking_doesNotExportSpan() async throws {
        LoggingSystem.bootstrapInternal(logLevel: .trace)

        let exporter = OTelStreamingSpanExporter()
        let clock = TestClock()
        var sleeps = clock.sleepCalls.makeAsyncIterator()
        let processor = OTelBatchSpanProcessor(
            exporter: exporter,
            configuration: .init(environment: [:], scheduleDelay: .seconds(2)),
            clock: clock
        )

        let span1 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "1")
        let span2 = OTelFinishedSpan.stub(traceFlags: [], operationName: "2")

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))
        Task {
            try await serviceGroup.run()
        }

        // add less than maximum queue size
        await processor.onEnd(span1)
        await processor.onEnd(span2)

        // await first sleep for "tick"
        await sleeps.next()
        clock.advance(by: .seconds(2))

        var batches = exporter.batches.makeAsyncIterator()
        let batch = await batches.next()
        XCTAssertEqual(try XCTUnwrap(batch).map(\.operationName), ["1"])
    }

    func test_onEnd_whenReachingMaximumQueueSize_triggersExplicitExportOfNextBatch() async throws {
        LoggingSystem.bootstrapInternal(logLevel: .trace)

        let exporter = OTelStreamingSpanExporter()
        let clock = TestClock()
        var sleeps = clock.sleepCalls.makeAsyncIterator()
        let processor = OTelBatchSpanProcessor(
            exporter: exporter,
            configuration: .init(environment: [:], maximumQueueSize: 3, scheduleDelay: .seconds(2)),
            clock: clock
        )

        let span1 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "1")
        let span2 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "2")
        let span3 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "3")

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))
        Task {
            try await serviceGroup.run()
        }

        // add less than maximum queue size
        await processor.onEnd(span1)
        await processor.onEnd(span2)

        // await first sleep for "tick" but don't advance clock
        await sleeps.next()

        // add final span to reach maximum queue size
        await processor.onEnd(span3)

        var batches = exporter.batches.makeAsyncIterator()
        let batch = await batches.next()
        XCTAssertEqual(try XCTUnwrap(batch).map(\.operationName), ["1", "2", "3"])
    }

    func test_onEnd_whenExportFails_keepsExportingFutureSpans() async throws {
        LoggingSystem.bootstrapInternal(logLevel: .trace)

        struct TestError: Error {}
        let exporter = OTelStreamingSpanExporter()

        let clock = TestClock()
        var sleeps = clock.sleepCalls.makeAsyncIterator()
        let processor = OTelBatchSpanProcessor(
            exporter: exporter,
            configuration: .init(environment: [:], scheduleDelay: .seconds(2)),
            clock: clock
        )

        let span1 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "1")
        let span2 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "2")

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))
        Task {
            try await serviceGroup.run()
        }

        await exporter.setErrorDuringNextExport(TestError())
        await processor.onEnd(span1)

        // await sleep for first "tick"
        await sleeps.next()
        clock.advance(by: .seconds(2))
        // await sleep for export timeout
        await sleeps.next()

        var batches = exporter.batches.makeAsyncIterator()
        let failedBatch = await batches.next()
        XCTAssertEqual(try XCTUnwrap(failedBatch).map { $0.map(\.operationName) }, ["1"])

        await processor.onEnd(span2)

        // await sleep for second "tick"
        await sleeps.next()
        clock.advance(by: .seconds(2))
        // await sleep for export timeout
        await sleeps.next()

        let successfulBatch = await batches.next()
        XCTAssertEqual(try XCTUnwrap(successfulBatch).map { $0.map(\.operationName) }, ["2"])
    }

    func test_run_onGracefulShutdown_forceFlushesRemainingSpans_shutsDownExporter() async throws {
        LoggingSystem.bootstrapInternal(logLevel: .trace)

        let exporter = OTelInMemorySpanExporter()
        let clock = TestClock()
        var sleeps = clock.sleepCalls.makeAsyncIterator()
        let processor = OTelBatchSpanProcessor(
            exporter: exporter,
            configuration: .init(environment: [:], maximumExportBatchSize: 2),
            clock: clock
        )

        for i in 1 ... 3 {
            let span = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "\(i)")
            await processor.onEnd(span)
        }

        let finishExpectation = expectation(description: "Expected processor to finish shutting down.")

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))
        Task {
            try await serviceGroup.run()
            finishExpectation.fulfill()
        }

        // await first sleep for "tick" before triggering graceful shutdown
        await sleeps.next()
        await serviceGroup.triggerGracefulShutdown()

        await fulfillment(of: [finishExpectation], timeout: 0.1)

        let exportedBatches = await exporter.exportedBatches
        XCTAssertEqual(
            exportedBatches.map { $0.map(\.operationName) }.sorted(by: { $0.count > $1.count }),
            [["1", "2"], ["3"]]
        )

        let numberOfExporterForceFlushes = await exporter.numberOfForceFlushes
        XCTAssertEqual(numberOfExporterForceFlushes, 1)
        let numberOfExporterShutdowns = await exporter.numberOfShutdowns
        XCTAssertEqual(numberOfExporterShutdowns, 1)
    }

    func test_run_onGracefulShutdown_whenForceFlushTimesOut_shutsDownExporter() async throws {
        LoggingSystem.bootstrapInternal(logLevel: .trace)

        let exporter = OTelInMemorySpanExporter(exportDelay: .seconds(5))
        let clock = TestClock()
        var sleeps = clock.sleepCalls.makeAsyncIterator()
        let processor = OTelBatchSpanProcessor(
            exporter: exporter,
            configuration: .init(environment: [:], exportTimeout: .seconds(1)),
            clock: clock
        )

        for _ in 1 ... 100 {
            let span = OTelFinishedSpan.stub(traceFlags: .sampled)
            await processor.onEnd(span)
        }

        let finishExpectation = expectation(description: "Expected processor to finish shutting down.")

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))
        Task {
            try await serviceGroup.run()
            finishExpectation.fulfill()
        }

        // await first sleep for "tick" before triggering graceful shutdown
        await sleeps.next()
        await serviceGroup.triggerGracefulShutdown()

        // await flush timeout sleep
        await sleeps.next()
        // advance past flush timeout
        clock.advance(by: .seconds(2))

        await fulfillment(of: [finishExpectation], timeout: 0.1)

        let exportedBatches = await exporter.exportedBatches
        XCTAssertTrue(exportedBatches.isEmpty)

        let numberOfExporterForceFlushes = await exporter.numberOfForceFlushes
        XCTAssertEqual(numberOfExporterForceFlushes, 1)
        let numberOfExporterShutdowns = await exporter.numberOfShutdowns
        XCTAssertEqual(numberOfExporterShutdowns, 1)
    }
}

extension OTelBatchSpanProcessor {
    // Overload with logging disabled.
    init(exporter: Exporter, configuration: OTelBatchSpanProcessorConfiguration, clock: Clock) {
        self.init(exporter: exporter, configuration: configuration, logger: ._otelDisabled, clock: clock)
    }
}

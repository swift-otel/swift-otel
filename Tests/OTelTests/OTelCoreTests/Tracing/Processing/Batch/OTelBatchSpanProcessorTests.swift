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
            configuration: .defaultWith(scheduleDelay: .seconds(2)),
            clock: clock
        )

        let span1 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "1")
        let span2 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "2")
        let span3 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "3")

        let serviceGroup = ServiceGroup(services: [exporter, processor], logger: Logger(label: #function))
        Task {
            try await serviceGroup.run()
        }

        processor.onEnd(span1)
        processor.onEnd(span2)
        processor.onEnd(span3)

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
            configuration: .defaultWith(scheduleDelay: .seconds(2)),
            clock: clock
        )

        let span1 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "1")
        let span2 = OTelFinishedSpan.stub(traceFlags: [], operationName: "2")

        let serviceGroup = ServiceGroup(services: [exporter, processor], logger: Logger(label: #function))
        Task {
            try await serviceGroup.run()
        }

        // add less than maximum queue size
        processor.onEnd(span1)
        processor.onEnd(span2)

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
            configuration: .defaultWith(scheduleDelay: .seconds(2), maxQueueSize: 3),
            clock: clock
        )

        let span1 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "1")
        let span2 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "2")
        let span3 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "3")

        let serviceGroup = ServiceGroup(services: [exporter, processor], logger: Logger(label: #function))
        Task {
            try await serviceGroup.run()
        }

        // add less than maximum queue size
        processor.onEnd(span1)
        processor.onEnd(span2)

        // await first sleep for "tick" but don't advance clock
        await sleeps.next()

        // add final span to reach maximum queue size
        processor.onEnd(span3)

        var batches = exporter.batches.makeAsyncIterator()
        let batch = await batches.next()
        XCTAssertEqual(try XCTUnwrap(batch).map(\.operationName), ["1", "2", "3"])
    }

    func test_onEnd_whenBufferIsFull_nextTickEmitsDiagnostic() async throws {
        let recordingLogHander = RecordingLogHandler()
        let logger = Logger(label: "test") { _ in recordingLogHander }
        let processorClock = TestClock()
        let exporterClock = TestClock()
        var processorSleeps = processorClock.sleepCalls.makeAsyncIterator()
        var exporterSleeps = exporterClock.sleepCalls.makeAsyncIterator()
        let scheduleDelay = Duration.seconds(1)
        let exportDelay = Duration.seconds(1)
        let exportTimeout = Duration.seconds(0.5)
        let exporter = SlowMockExporter(clock: exporterClock, delay: exportDelay)
        let processor = OTelBatchSpanProcessor(
            exporter: exporter,
            configuration: .defaultWith(scheduleDelay: scheduleDelay, exportTimeout: exportTimeout, maxQueueSize: 2),
            logger: logger,
            clock: processorClock
        )
        let serviceGroup = ServiceGroup(services: [exporter, processor], logger: logger)

        let span1 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "1")
        let span2 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "2")
        let span3 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "3")

        try await withThrowingTaskGroup { group in
            group.addTask { try await serviceGroup.run() }

            // Wait for tick.
            await processorSleeps.next()

            // Fill the buffer (for the BSP, this triggers an explicit tick).
            processor.onEnd(span1)
            processor.onEnd(span2)

            // Wait for the exporter timeout to start.
            await processorSleeps.next()
            // Wait for the exporter to be kicked.
            await exporterSleeps.next()

            // While the export is ongoing, overfill the buffer.
            processor.onEnd(span1)
            processor.onEnd(span2)
            processor.onEnd(span3)

            // Unblock the exporter.
            exporterClock.advance(by: exportDelay)

            // Await next processor tick and advance.
            await processorSleeps.next()
            processorClock.advance(by: scheduleDelay)

            // Check for logs.
            let _log = await recordingLogHander.recordedLogMessageStream.first { $0.level == .warning }
            let log = try XCTUnwrap(_log)
            XCTAssert(log.message.description.contains("Spans were dropped"))
            XCTAssertEqual(log.metadata?["dropped_count"], "\(1)")

            await serviceGroup.triggerGracefulShutdown()
            try await group.waitForAll()
        }
    }

    func test_onEnd_whenExportFails_keepsExportingFutureSpans() async throws {
        LoggingSystem.bootstrapInternal(logLevel: .trace)

        struct TestError: Error {}
        let exporter = OTelStreamingSpanExporter()

        let clock = TestClock()
        var sleeps = clock.sleepCalls.makeAsyncIterator()
        let processor = OTelBatchSpanProcessor(
            exporter: exporter,
            configuration: .defaultWith(scheduleDelay: .seconds(2)),
            clock: clock
        )

        let span1 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "1")
        let span2 = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "2")

        let serviceGroup = ServiceGroup(services: [exporter, processor], logger: Logger(label: #function))
        Task {
            try await serviceGroup.run()
        }

        await exporter.setErrorDuringNextExport(TestError())
        processor.onEnd(span1)

        // await sleep for first "tick"
        await sleeps.next()
        clock.advance(by: .seconds(2))
        // await sleep for export timeout
        await sleeps.next()

        var batches = exporter.batches.makeAsyncIterator()
        let failedBatch = await batches.next()
        XCTAssertEqual(try XCTUnwrap(failedBatch).map { $0.map(\.operationName) }, ["1"])

        processor.onEnd(span2)

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
            configuration: .defaultWith(maxExportBatchSize: 2),
            clock: clock
        )

        for i in 1 ... 3 {
            let span = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "\(i)")
            processor.onEnd(span)
        }

        let finishExpectation = expectation(description: "Expected processor to finish shutting down.")

        let serviceGroup = ServiceGroup(services: [exporter, processor], logger: Logger(label: #function))
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
            configuration: .defaultWith(exportTimeout: .seconds(1)),
            clock: clock
        )

        for _ in 1 ... 100 {
            let span = OTelFinishedSpan.stub(traceFlags: .sampled)
            processor.onEnd(span)
        }

        let finishExpectation = expectation(description: "Expected processor to finish shutting down.")

        let serviceGroup = ServiceGroup(services: [exporter, processor], logger: Logger(label: #function))
        Task {
            do {
                try await serviceGroup.run()
            } catch {
                finishExpectation.fulfill()
            }
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

    func test_run_exporterRunMethodFinishes_shutsDownProcessor() async throws {
        struct ExitingExporter: OTelSpanExporter {
            let trigger = AsyncStream<Void>.makeStream(of: Void.self)
            func run() async throws {
                await trigger.stream.first { true }
            }

            func export(_ batch: some Collection<OTelFinishedSpan> & Sendable) async throws {}
            func forceFlush() async throws {}
            func shutdown() async {}
        }

        let exporter = ExitingExporter()
        let processorClock = TestClock()
        let processor = OTelBatchSpanProcessor(
            exporter: exporter,
            configuration: .defaultWith(scheduleDelay: .seconds(1), exportTimeout: .seconds(1)),
            clock: processorClock
        )

        try await withThrowingTaskGroup { group in
            group.addTask {
                let serviceGroup = ServiceGroup(services: [exporter, processor], logger: Logger(label: #function))
                try await serviceGroup.run()
                XCTFail("Expected service group task throw")
            }

            var processorSleeps = processorClock.sleepCalls.makeAsyncIterator()
            await processorSleeps.next()
            exporter.trigger.continuation.yield()

            do {
                try await group.next()
                XCTFail("Expected service group task throw")
            } catch {
                let serviceGroupError = try XCTUnwrap(error as? ServiceGroupError)
                XCTAssertEqual(serviceGroupError, ServiceGroupError.serviceFinishedUnexpectedly())
            }
        }
    }

    func test_run_exporterRunMethodThrows_shutsDownProcessor() async throws {
        struct ThrowingExporter: OTelSpanExporter {
            let trigger = AsyncStream<Void>.makeStream(of: Void.self)
            func run() async throws {
                await trigger.stream.first(where: { true })
                throw ExporterFailed()
            }

            struct ExporterFailed: Error {}
            func export(_ batch: some Collection<OTelFinishedSpan> & Sendable) async throws {}
            func forceFlush() async throws {}
            func shutdown() async {}
        }

        let exporter = ThrowingExporter()
        let processorClock = TestClock()
        let processor = OTelBatchSpanProcessor(
            exporter: exporter,
            configuration: .defaultWith(scheduleDelay: .seconds(1), exportTimeout: .seconds(1)),
            clock: processorClock
        )

        try await withThrowingTaskGroup { group in
            group.addTask {
                let serviceGroup = ServiceGroup(services: [exporter, processor], logger: Logger(label: #function))
                try await serviceGroup.run()
                XCTFail("Expected service group task throw")
            }

            var processorSleeps = processorClock.sleepCalls.makeAsyncIterator()
            await processorSleeps.next()
            exporter.trigger.continuation.yield()

            do {
                try await group.next()
                XCTFail("Expected service group task throw")
            } catch {
                XCTAssert(error is ThrowingExporter.ExporterFailed, "Different error: \(error)")
            }
            try await group.waitForAll()
        }
    }
}

extension OTelBatchSpanProcessor {
    // Overload with logging disabled.
    init(exporter: Exporter, configuration: OTel.Configuration.TracesConfiguration.BatchSpanProcessorConfiguration, clock: Clock) {
        self.init(exporter: exporter, configuration: configuration, logger: ._otelDisabled, clock: clock)
    }
}

extension OTel.Configuration.TracesConfiguration.BatchSpanProcessorConfiguration {
    // Overload with defaults.
    static func defaultWith(
        scheduleDelay: Duration = Self.default.scheduleDelay,
        exportTimeout: Duration = Self.default.exportTimeout,
        maxQueueSize: Int = Self.default.maxQueueSize,
        maxExportBatchSize: Int = Self.default.maxExportBatchSize
    ) -> Self {
        Self(scheduleDelay: scheduleDelay, exportTimeout: exportTimeout, maxQueueSize: maxQueueSize, maxExportBatchSize: maxExportBatchSize)
    }
}

struct SlowMockExporter<Clock: _Concurrency.Clock>: OTelSpanExporter where Clock.Duration == Duration {
    var clock: Clock
    var delay: Duration

    func run() async throws { try await gracefulShutdown() }

    func export(_ batch: some Collection<OTelFinishedSpan> & Sendable) async throws {
        try await Task.sleep(for: delay, clock: clock)
    }

    func forceFlush() async throws {}

    func shutdown() async {}
}

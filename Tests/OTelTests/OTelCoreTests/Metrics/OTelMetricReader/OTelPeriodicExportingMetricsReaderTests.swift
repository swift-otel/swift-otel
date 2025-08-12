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
import NIOConcurrencyHelpers
@testable import OTel
import ServiceLifecycle
import XCTest

final class OTelPeriodicExportingMetricsReaderTests: XCTestCase {
    func test_normalBehavior_periodicallyExports() async throws {
        let clock = TestClock()
        let exporter = RecordingMetricExporter()
        let producer = MockMetricProducer()
        let reader = OTelPeriodicExportingMetricsReader(
            resource: .init(),
            producer: producer,
            exporter: exporter,
            configuration: .defaultWith(exportInterval: .seconds(1), exportTimeout: .milliseconds(100)),
            clock: clock
        )
        _ = reader.description
        var sleepCalls = clock.sleepCalls.makeAsyncIterator()
        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await reader.run()
            }

            // await sleep for tick.
            await sleepCalls.next()

            // while the timer sequence is sleeping, check the expected producer and exporter counts.
            producer.assert(produceCallCount: 0)
            exporter.assert(exportCallCount: 0, forceFlushCallCount: 0, shutdownCallCount: 0)

            // advance the clock for the tick.
            clock.advance(to: .seconds(1))

            // await sleep for export timeout and advance passed it.
            await sleepCalls.next()
            clock.advance(by: .milliseconds(200))

            // await sleep for tick.
            await sleepCalls.next()

            // while the timer sequence is sleeping, check the expected producer and exporter counts.
            producer.assert(produceCallCount: 1)
            exporter.assert(exportCallCount: 1, forceFlushCallCount: 0, shutdownCallCount: 0)

            // advance the clock for the tick.
            clock.advance(to: .seconds(2))

            // await sleep for export timeout and advance passed it.
            await sleepCalls.next()
            clock.advance(by: .milliseconds(200))

            // await sleep for tick.
            await sleepCalls.next()

            // while the timer sequence is sleeping, check the expected producer and exporter counts.
            producer.assert(produceCallCount: 2)
            exporter.assert(exportCallCount: 2, forceFlushCallCount: 0, shutdownCallCount: 0)

            group.cancelAll()
        }
    }

    func test_onGracefulShutdown_exportsAndShutsDown() async throws {
        let clock = TestClock()
        let exporter = RecordingMetricExporter()
        let producer = MockMetricProducer()
        let reader = OTelPeriodicExportingMetricsReader(
            resource: .init(),
            producer: producer,
            exporter: exporter,
            configuration: .defaultWith(exportInterval: .seconds(1), exportTimeout: .milliseconds(100)),
            clock: clock
        )
        let serviceGroup = ServiceGroup(services: [reader], logger: Logger(label: #function))
        var sleepCalls = clock.sleepCalls.makeAsyncIterator()
        try await withThrowingTaskGroup(of: Void.self) { group in
            let shutdownExpectation = expectation(description: "Expected service group to finish shutting down.")
            group.addTask {
                try await serviceGroup.run()
                shutdownExpectation.fulfill()
            }

            // await sleep for tick.
            await sleepCalls.next()

            // while the timer sequence is sleeping, check the expected producer and exporter counts.
            producer.assert(produceCallCount: 0)
            exporter.assert(exportCallCount: 0, forceFlushCallCount: 0, shutdownCallCount: 0)

            // trigger graceful shutdown
            await serviceGroup.triggerGracefulShutdown()

            // await flush timeout sleep
            await sleepCalls.next()
            // advance past flush timeout
            clock.advance(by: .seconds(2))

            await fulfillment(of: [shutdownExpectation], timeout: 0.1)

            // check we did a final metric production, export, then shutdown the exporter.
            producer.assert(produceCallCount: 1)
            exporter.assert(exportCallCount: 1, forceFlushCallCount: 1, shutdownCallCount: 1)

            try await group.waitForAll()
        }
    }

    func test_exportTakesLongerThanTimeout_logsWarning() async throws {
        let recordingLogHandler = RecordingLogHandler()
        let recordingLogger = Logger(label: "test", recordingLogHandler)
        let clock = TestClock()
        let exporter = MockMetricExporter(behavior: .sleep)
        let producer = MockMetricProducer()
        let reader = OTelPeriodicExportingMetricsReader(
            resource: .init(),
            producer: producer,
            exporter: exporter,
            configuration: .defaultWith(exportInterval: .seconds(1), exportTimeout: .milliseconds(100)),
            logger: recordingLogger,
            clock: clock
        )
        var sleepCalls = clock.sleepCalls.makeAsyncIterator()
        var warningLogs = recordingLogHandler.recordedLogMessageStream.filter { $0.level == .warning }.makeAsyncIterator()
        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await reader.run()
            }

            // await sleep for tick.
            await sleepCalls.next()

            // while the timer sequence is sleeping, check the export cancellation and warning log counts.
            XCTAssertEqual(recordingLogHandler.warningCount, 0)
            XCTAssertEqual(exporter.cancellationCount.withLockedValue { $0 }, 0)

            // advance the clock for the tick.
            clock.advance(to: .seconds(1))

            // await sleep for export timeout and advance passed it.
            await sleepCalls.next()
            clock.advance(by: .milliseconds(200))
            _ = await warningLogs.next()

            // await sleep for tick.
            await sleepCalls.next()

            // while the timer sequence is sleeping, check the export cancellation and warning log counts.
            XCTAssertEqual(recordingLogHandler.warningCount, 1)
            XCTAssertEqual(exporter.cancellationCount.withLockedValue { $0 }, 1)

            // advance the clock for the tick.
            clock.advance(to: .seconds(2))

            // await sleep for export timeout and advance passed it.
            await sleepCalls.next()
            clock.advance(by: .milliseconds(200))
            _ = await warningLogs.next()

            // await sleep for tick.
            await sleepCalls.next()

            // while the timer sequence is sleeping, check the export cancellation and warning log counts.
            XCTAssertEqual(recordingLogHandler.warningCount, 2)
            XCTAssertEqual(exporter.cancellationCount.withLockedValue { $0 }, 2)

            group.cancelAll()
        }
    }

    func test_exportThrowsError_logsError() async throws {
        let recordingLogHandler = RecordingLogHandler()
        let recordingLogger = Logger(label: "test", recordingLogHandler)
        let clock = TestClock()
        let exporter = MockMetricExporter(behavior: .throw)
        let producer = MockMetricProducer()
        let reader = OTelPeriodicExportingMetricsReader(
            resource: .init(),
            producer: producer,
            exporter: exporter,
            configuration: .defaultWith(exportInterval: .seconds(1), exportTimeout: .milliseconds(100)),
            logger: recordingLogger,
            clock: clock
        )
        var sleepCalls = clock.sleepCalls.makeAsyncIterator()
        var errorLogs = recordingLogHandler.recordedLogMessageStream.filter { $0.level == .error }.makeAsyncIterator()
        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await reader.run()
            }

            // await sleep for tick.
            await sleepCalls.next()

            // while the timer sequence is sleeping, check the export throw and error log counts.
            XCTAssertEqual(recordingLogHandler.errorCount, 0)
            XCTAssertEqual(exporter.throwCount.withLockedValue { $0 }, 0)

            // advance the clock for the tick.
            clock.advance(to: .seconds(1))

            // await sleep for export timeout.
            await sleepCalls.next()
            _ = await errorLogs.next()

            // await sleep for tick.
            await sleepCalls.next()

            // while the timer sequence is sleeping, check the export cancellation and error log counts.
            XCTAssertEqual(recordingLogHandler.errorCount, 1)
            XCTAssertEqual(exporter.throwCount.withLockedValue { $0 }, 1)

            // advance the clock for the tick.
            clock.advance(to: .seconds(2))

            // await sleep for export timeout and advance passed it.
            await sleepCalls.next()
            _ = await errorLogs.next()

            // await sleep for tick.
            await sleepCalls.next()

            // while the timer sequence is sleeping, check the export cancellation and error log counts.
            XCTAssertEqual(recordingLogHandler.errorCount, 2)
            XCTAssertEqual(exporter.throwCount.withLockedValue { $0 }, 2)

            group.cancelAll()
        }
    }

    func test_initalizer_usesContinuousClockByDefault() {
        let reader = OTelPeriodicExportingMetricsReader(
            resource: .init(),
            producer: MockMetricProducer(),
            exporter: RecordingMetricExporter(),
            configuration: .default
        )
        XCTAssert(type(of: reader.clock) == ContinuousClock.self)
    }

    func test_run_exporterRunMethodFinishes_shutsDownReader() async throws {
        struct ExitingExporter: OTelMetricExporter {
            let trigger = AsyncStream<Void>.makeStream(of: Void.self)
            func run() async throws {
                await trigger.stream.first { true }
            }

            func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws {}
            func forceFlush() async throws {}
            func shutdown() async {}
        }

        let readerClock = TestClock()
        let exporter = ExitingExporter()
        let producer = MockMetricProducer()
        let reader = OTelPeriodicExportingMetricsReader(
            resource: .init(),
            producer: producer,
            exporter: exporter,
            configuration: .defaultWith(exportInterval: .seconds(1), exportTimeout: .milliseconds(100)),
            logger: ._otelDebug,
            clock: readerClock
        )

        try await withThrowingTaskGroup { group in
            group.addTask {
                let serviceGroup = ServiceGroup(services: [exporter, reader], logger: Logger(label: #function))
                try await serviceGroup.run()
                XCTFail("Expected service group task throw")
            }

            var readerSleeps = readerClock.sleepCalls.makeAsyncIterator()
            await readerSleeps.next()
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

    func test_run_exporterRunMethodThrows_shutsDownReader() async throws {
        struct ThrowingExporter: OTelMetricExporter {
            let trigger = AsyncStream<Void>.makeStream(of: Void.self)
            func run() async throws {
                await trigger.stream.first(where: { true })
                throw ExporterFailed()
            }

            struct ExporterFailed: Error {}
            func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws {}
            func forceFlush() async throws {}
            func shutdown() async {}
        }

        let readerClock = TestClock()
        let exporter = ThrowingExporter()
        let producer = MockMetricProducer()
        let reader = OTelPeriodicExportingMetricsReader(
            resource: .init(),
            producer: producer,
            exporter: exporter,
            configuration: .defaultWith(exportInterval: .seconds(1), exportTimeout: .milliseconds(100)),
            logger: ._otelDebug,
            clock: readerClock
        )

        try await withThrowingTaskGroup { group in
            group.addTask {
                let serviceGroup = ServiceGroup(services: [exporter, reader], logger: Logger(label: #function))
                try await serviceGroup.run()
                XCTFail("Expected service group task throw")
            }

            var readerSleeps = readerClock.sleepCalls.makeAsyncIterator()
            await readerSleeps.next()
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

// MARK: - Helpers

final class MockMetricProducer: Sendable, OTelMetricProducer {
    let produceReturnValue = NIOLockedValueBox([OTelMetricPoint]())
    let produceCallCount = NIOLockedValueBox(0)
    func produce() -> [OTelMetricPoint] {
        produceCallCount.withLockedValue { $0 += 1 }
        return produceReturnValue.withLockedValue { $0 }
    }

    func assert(produceCallCount: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(self.produceCallCount.withLockedValue { $0 }, produceCallCount, file: file, line: line)
    }
}

final class MockMetricExporter: Sendable, OTelMetricExporter {
    struct MockError: Error {}

    enum Behavior {
        case sleep
        case `throw`
    }

    let behavior: Behavior

    let cancellationCount = NIOLockedValueBox(0)
    let throwCount = NIOLockedValueBox(0)
    let forceFlushCount = NIOLockedValueBox(0)
    let shutdownCount = NIOLockedValueBox(0)

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func run() async throws {
        // No background work needed, but we'll keep the run method running until its cancelled.
        try await gracefulShutdown()
    }

    func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws {
        switch behavior {
        case .sleep:
            try await withTaskCancellationHandler {
                while true {
                    try await Task.sleep(for: .seconds(60))
                }
            } onCancel: {
                cancellationCount.withLockedValue { $0 += 1 }
            }
        case .throw:
            throwCount.withLockedValue { $0 += 1 }
            throw MockError()
        }
    }

    func forceFlush() async throws {
        forceFlushCount.withLockedValue { $0 += 1 }
    }

    func shutdown() async {
        shutdownCount.withLockedValue { $0 += 1 }
    }
}

extension OTelPeriodicExportingMetricsReader {
    // Overload with logging disabled.
    init(
        resource: OTelResource,
        producer: OTelMetricProducer,
        exporter: OTelMetricExporter,
        configuration: OTel.Configuration.MetricsConfiguration,
        clock: Clock = .continuous
    ) {
        self.init(
            resource: resource,
            producer: producer,
            exporter: exporter,
            configuration: configuration,
            logger: ._otelDisabled,
            clock: clock
        )
    }
}

extension OTel.Configuration.MetricsConfiguration {
    // Overload with defaults.
    static func defaultWith(
        enabled: Bool = Self.default.enabled,
        exportInterval: Duration = Self.default.exportInterval,
        exportTimeout: Duration = Self.default.exportTimeout,
        exporter: ExporterSelection = Self.default.exporter,
        otlpExporter: OTel.Configuration.OTLPExporterConfiguration = Self.default.otlpExporter
    ) -> Self {
        self.init(enabled: enabled, exportInterval: exportInterval, exportTimeout: exportTimeout, exporter: exporter, otlpExporter: otlpExporter)
    }
}

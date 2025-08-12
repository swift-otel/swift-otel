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

final class OTelBatchLogRecordProcessorTests: XCTestCase {
    override func setUp() {
        LoggingSystem.bootstrapInternal(logLevel: .trace)
    }

    func test_onEmit_whenTicking_exportsNextBatch() async throws {
        let exporter = OTelStreamingLogRecordExporter()
        let clock = TestClock()
        let scheduleDelay = Duration.seconds(1)
        let processor = OTelBatchLogRecordProcessor(
            exporter: exporter,
            configuration: .defaultWith(scheduleDelay: scheduleDelay),
            clock: clock
        )

        let serviceGroup = ServiceGroup(services: [exporter, processor], logger: Logger(label: #function))

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(operation: serviceGroup.run)

            let messages: [Logger.Message] = (1 ... 3).map { "\($0)" }
            for message in messages {
                var record = OTelLogRecord.stub(body: message)
                processor.onEmit(&record)
            }

            while await processor.buffer.count != messages.count { await Task.yield() }

            // await first sleep for "tick"
            var sleeps = clock.sleepCalls.makeAsyncIterator()
            await sleeps.next()
            // advance past "tick"
            clock.advance(by: scheduleDelay)

            var batches = exporter.batches.makeAsyncIterator()
            let batch = await batches.next()
            XCTAssertEqual(try XCTUnwrap(batch).map(\.body), messages)

            group.cancelAll()
        }
    }

    func test_onEmit_whenBufferIsFull_nextTickEmitsDiagnostic() async throws {
        let recordingLogHander = RecordingLogHandler()
        let logger = Logger(label: "test") { _ in recordingLogHander }
        let clock = TestClock()
        var sleeps = clock.sleepCalls.makeAsyncIterator()
        let scheduleDelay = Duration.seconds(1)
        let exporter = OTelStreamingLogRecordExporter()
        let processor = OTelBatchLogRecordProcessor(
            exporter: exporter,
            configuration: .defaultWith(maxQueueSize: 2),
            logger: logger,
            clock: clock
        )
        let serviceGroup = ServiceGroup(services: [exporter, processor], logger: logger)

        var record1 = OTelLogRecord.stub(body: "1")
        var record2 = OTelLogRecord.stub(body: "2")
        var record3 = OTelLogRecord.stub(body: "3")

        try await withThrowingTaskGroup { group in
            group.addTask { try await serviceGroup.run() }

            await sleeps.next()

            processor.onEmit(&record1)
            processor.onEmit(&record2)
            processor.onEmit(&record3)
            while await (processor.buffer.count, processor.droppedCount) != (2, 1) { await Task.yield() }

            clock.advance(by: scheduleDelay)

            let _log = await recordingLogHander.recordedLogMessageStream.first { $0.level == .warning }
            let log = try XCTUnwrap(_log)
            XCTAssert(log.message.description.contains("Log records were dropped"))
            XCTAssertEqual(log.metadata?["dropped_count"], "\(1)")

            await serviceGroup.triggerGracefulShutdown()
            try await group.waitForAll()
        }
    }

    func test_onEmit_whenExportFails_keepsExportingFutureLogRecords() async throws {
        LoggingSystem.bootstrapInternal(logLevel: .trace)

        struct TestError: Error {}
        let exporter = OTelStreamingLogRecordExporter()

        let clock = TestClock()
        let scheduleDelay = Duration.seconds(1)
        let processor = OTelBatchLogRecordProcessor(
            exporter: exporter,
            configuration: .defaultWith(scheduleDelay: scheduleDelay),
            clock: clock
        )

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(operation: serviceGroup.run)
            var sleeps = clock.sleepCalls.makeAsyncIterator()

            await exporter.setErrorDuringNextExport(TestError())
            var record1 = OTelLogRecord.stub(body: "1")
            processor.onEmit(&record1)
            while await processor.buffer.count != 1 { await Task.yield() }

            // await sleep for first "tick"
            await sleeps.next()
            // advance past "tick"
            clock.advance(by: scheduleDelay)
            // await sleep for export timeout
            await sleeps.next()

            var batches = exporter.batches.makeAsyncIterator()
            let failedBatch = await batches.next()
            XCTAssertEqual(try XCTUnwrap(failedBatch).map(\.body), ["1"])

            var record2 = OTelLogRecord.stub(body: "2")
            processor.onEmit(&record2)

            // await sleep for first "tick"
            await sleeps.next()
            // advance past "tick"
            clock.advance(by: scheduleDelay)
            // await sleep for export timeout
            await sleeps.next()

            let successfulBatch = await batches.next()
            XCTAssertEqual(try XCTUnwrap(successfulBatch).map(\.body), ["2"])

            group.cancelAll()
        }
    }

    func test_onEmit_whenExportExceedsTimeout_cancelsExport() async throws {
        let exportTimeout = Duration.seconds(1)
        let exporter = OTelInMemoryLogRecordExporter(exportDelay: exportTimeout * 2)
        let clock = TestClock()
        let scheduleDelay = Duration.seconds(3)
        let processor = OTelBatchLogRecordProcessor(
            exporter: exporter,
            configuration: .defaultWith(scheduleDelay: scheduleDelay, exportTimeout: exportTimeout),
            clock: clock
        )

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))

        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(operation: serviceGroup.run)

            var record = OTelLogRecord.stub()
            processor.onEmit(&record)

            while await processor.buffer.count != 1 { await Task.yield() }

            var sleeps = clock.sleepCalls.makeAsyncIterator()

            // advance past first "tick"
            await sleeps.next()
            clock.advance(by: scheduleDelay)

            // advance past export timeout
            await sleeps.next()
            clock.advance(by: exportTimeout)

            // await sleep for next "tick"
            await sleeps.next()

            let numberOfExportCancellations = await exporter.numberOfExportCancellations
            XCTAssertEqual(numberOfExportCancellations, 1)

            group.cancelAll()
        }
    }

    func test_run_onGracefulShutdown_forceFlushesRemainingLogRecords_shutsDownExporter() async throws {
        LoggingSystem.bootstrapInternal(logLevel: .trace)

        let exporter = OTelStreamingLogRecordExporter()
        let clock = TestClock()
        let processor = OTelBatchLogRecordProcessor(
            exporter: exporter,
            configuration: .defaultWith(maxExportBatchSize: 1),
            clock: clock
        )

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))
        let messages = Set(["1", "2", "3"])

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(operation: serviceGroup.run)

            for message in messages {
                var record = OTelLogRecord.stub(body: "\(message)")
                processor.onEmit(&record)
            }

            while await processor.buffer.count != messages.count { await Task.yield() }

            var sleeps = clock.sleepCalls.makeAsyncIterator()
            // await sleep for first "tick"
            await sleeps.next()

            await serviceGroup.triggerGracefulShutdown()

            var batches = exporter.batches.makeAsyncIterator()
            /*
             Forced flush exports occur concurrently, so we check that all messages got exported,
             without checking the specific order they were exported in.
             */
            var exportedMessages = Set<String>()
            for _ in messages {
                let batch = await batches.next()
                for logRecord in try XCTUnwrap(batch) {
                    exportedMessages.insert("\(logRecord.body)")
                }
            }
            XCTAssertEqual(exportedMessages, messages)
        }

        let numberOfForceFlushes = await exporter.numberOfForceFlushes
        XCTAssertEqual(numberOfForceFlushes, 1)
        let numberOfShutdowns = await exporter.numberOfShutdowns
        XCTAssertEqual(numberOfShutdowns, 1)
    }

    func test_run_onGracefulShutdown_whenForceFlushTimesOut_shutsDownExporter() async throws {
        LoggingSystem.bootstrapInternal(logLevel: .trace)

        let exportTimeout = Duration.seconds(1)
        let exporter = OTelInMemoryLogRecordExporter(exportDelay: exportTimeout * 2)
        let clock = TestClock()
        let scheduleDelay = Duration.seconds(3)
        let processor = OTelBatchLogRecordProcessor(
            exporter: exporter,
            configuration: .defaultWith(scheduleDelay: scheduleDelay, exportTimeout: exportTimeout),
            clock: clock
        )

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))
        let messages = Set(["1", "2", "3"])

        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(operation: serviceGroup.run)

            for message in messages {
                var record = OTelLogRecord.stub(body: "\(message)")
                processor.onEmit(&record)
            }

            while await processor.buffer.count != messages.count { await Task.yield() }

            var sleeps = clock.sleepCalls.makeAsyncIterator()
            // await sleep for first "tick"
            await sleeps.next()

            await serviceGroup.triggerGracefulShutdown()

            // advance past export timeout
            await sleeps.next()
            clock.advance(by: exportTimeout)
        }

        let numberOfShutdowns = await exporter.numberOfShutdowns
        XCTAssertEqual(numberOfShutdowns, 1)
    }

    func test_run_exporterRunMethodFinishes_shutsDownProcessor() async throws {
        struct ExitingExporter: OTelLogRecordExporter {
            let trigger = AsyncStream<Void>.makeStream(of: Void.self)
            func run() async throws {
                await trigger.stream.first { true }
            }

            func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws {}
            func forceFlush() async throws {}
            func shutdown() async {}
        }

        let exporter = ExitingExporter()
        let processorClock = TestClock()
        let processor = OTelBatchLogRecordProcessor(
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
        struct ThrowingExporter: OTelLogRecordExporter {
            let trigger = AsyncStream<Void>.makeStream(of: Void.self)
            func run() async throws {
                await trigger.stream.first(where: { true })
                throw ExporterFailed()
            }

            struct ExporterFailed: Error {}
            func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws {}
            func forceFlush() async throws {}
            func shutdown() async {}
        }

        let exporter = ThrowingExporter()
        let processorClock = TestClock()
        let processor = OTelBatchLogRecordProcessor(
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

extension OTelBatchLogRecordProcessor {
    // Overload with logging disabled.
    init(exporter: Exporter, configuration: OTel.Configuration.LogsConfiguration.BatchLogRecordProcessorConfiguration, clock: Clock = .continuous) {
        self.init(exporter: exporter, configuration: configuration, logger: ._otelDisabled, clock: clock)
    }
}

extension OTel.Configuration.LogsConfiguration.BatchLogRecordProcessorConfiguration {
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

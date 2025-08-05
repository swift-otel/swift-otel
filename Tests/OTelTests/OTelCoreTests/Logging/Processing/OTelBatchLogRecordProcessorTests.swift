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
            configuration: .init(environment: [:], scheduleDelay: scheduleDelay),
            clock: clock
        )

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(operation: serviceGroup.run)

            let messages: [Logger.Message] = (1 ... 3).map { "\($0)" }
            for message in messages {
                var record = OTelLogRecord.stub(body: message)
                processor.onEmit(&record)
            }

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

    func test_onEmit_whenReachingMaximumQueueSize_triggersExplicitExportOfNextBatch() async throws {
        let exporter = OTelStreamingLogRecordExporter()
        let maximumQueueSize = UInt(2)
        let processor = OTelBatchLogRecordProcessor(
            exporter: exporter,
            configuration: .init(environment: [:], maximumQueueSize: maximumQueueSize)
        )

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(operation: serviceGroup.run)

            var record1 = OTelLogRecord.stub(body: "1")
            processor.onEmit(&record1)

            var record2 = OTelLogRecord.stub(body: "2")
            processor.onEmit(&record2)

            var batches = exporter.batches.makeAsyncIterator()
            let batch = await batches.next()
            XCTAssertEqual(try XCTUnwrap(batch).map(\.body), ["1", "2"])

            group.cancelAll()
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
            configuration: .init(environment: [:], scheduleDelay: scheduleDelay),
            clock: clock
        )

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(operation: serviceGroup.run)
            var sleeps = clock.sleepCalls.makeAsyncIterator()

            await exporter.setErrorDuringNextExport(TestError())
            var record1 = OTelLogRecord.stub(body: "1")
            processor.onEmit(&record1)

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
            configuration: .init(environment: [:], scheduleDelay: scheduleDelay, exportTimeout: exportTimeout),
            clock: clock
        )

        let serviceGroup = ServiceGroup(services: [processor], logger: Logger(label: #function))

        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(operation: serviceGroup.run)

            var record = OTelLogRecord.stub()
            processor.onEmit(&record)

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
            configuration: .init(environment: [:], maximumExportBatchSize: 1),
            clock: clock
        )

        let shutdownTrigger = ShutdownTrigger()
        let serviceGroup = ServiceGroup(
            configuration: .init(
                services: [
                    .init(service: shutdownTrigger, successTerminationBehavior: .gracefullyShutdownGroup),
                    .init(service: processor),
                ],
                logger: Logger(label: #function)
            )
        )

        let messages = Set(["1", "2", "3"])

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(operation: serviceGroup.run)

            for message in messages {
                var record = OTelLogRecord.stub(body: "\(message)")
                processor.onEmit(&record)
            }

            var sleeps = clock.sleepCalls.makeAsyncIterator()
            // await sleep for first "tick"
            await sleeps.next()

            shutdownTrigger.triggerGracefulShutdown()

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
            configuration: .init(environment: [:], scheduleDelay: scheduleDelay, exportTimeout: exportTimeout),
            clock: clock
        )

        let shutdownTrigger = ShutdownTrigger()
        let serviceGroup = ServiceGroup(
            configuration: .init(
                services: [
                    .init(service: shutdownTrigger, successTerminationBehavior: .gracefullyShutdownGroup),
                    .init(service: processor),
                ],
                logger: Logger(label: #function)
            )
        )

        let messages = Set(["1", "2", "3"])

        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(operation: serviceGroup.run)

            for message in messages {
                var record = OTelLogRecord.stub(body: "\(message)")
                processor.onEmit(&record)
            }

            var sleeps = clock.sleepCalls.makeAsyncIterator()
            // await sleep for first "tick"
            await sleeps.next()

            shutdownTrigger.triggerGracefulShutdown()

            // advance past export timeout
            await sleeps.next()
            clock.advance(by: exportTimeout)
        }

        let numberOfShutdowns = await exporter.numberOfShutdowns
        XCTAssertEqual(numberOfShutdowns, 1)
    }
}

private struct ShutdownTrigger: Service {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    func triggerGracefulShutdown() {
        continuation.yield(())
    }

    func run() async throws {
        var iterator = stream.makeAsyncIterator()
        await iterator.next()
    }
}

extension OTelBatchLogRecordProcessor {
    // Overload with logging disabled.
    init(exporter: Exporter, configuration: OTelBatchLogRecordProcessorConfiguration, clock: Clock = .continuous) {
        self.init(exporter: exporter, configuration: configuration, logger: ._otelDisabled, clock: clock)
    }
}

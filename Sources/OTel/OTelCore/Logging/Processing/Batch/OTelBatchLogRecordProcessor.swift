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

import AsyncAlgorithms
import DequeModule
import Logging
import ServiceLifecycle

/// A log processor that batches logs and forwards them to a configured exporter.
///
/// [OpenTelemetry Specification: Batching processor](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/logs/sdk.md#batching-processor)
actor OTelBatchLogRecordProcessor<Exporter: OTelLogRecordExporter, Clock: _Concurrency.Clock>:
    OTelLogRecordProcessor,
    Service,
    CustomStringConvertible
    where Clock.Duration == Duration
{
    nonisolated let description = "OTelBatchLogRecordProcessor"

    internal /* for testing */ private(set) var buffer: Deque<OTelLogRecord>

    private let exporter: Exporter
    private let configuration: OTelBatchLogRecordProcessorConfiguration
    private let clock: Clock
    private let logger: Logger
    private let logStream: AsyncStream<OTelLogRecord>
    private let logContinuation: AsyncStream<OTelLogRecord>.Continuation
    private let explicitTickStream: AsyncStream<Void>
    private let explicitTick: AsyncStream<Void>.Continuation

    init(exporter: Exporter, configuration: OTelBatchLogRecordProcessorConfiguration, logger: Logger, clock: Clock) {
        self.logger = logger.withMetadata(component: "OTelBatchLogRecordProcessor")
        self.exporter = exporter
        self.configuration = configuration
        self.clock = clock

        buffer = Deque(minimumCapacity: Int(configuration.maximumQueueSize))
        (explicitTickStream, explicitTick) = AsyncStream.makeStream()
        (logStream, logContinuation) = AsyncStream.makeStream()
    }

    nonisolated func onEmit(_ record: inout OTelLogRecord) {
        logContinuation.yield(record)
    }

    private func _onLog(_ log: OTelLogRecord) {
        buffer.append(log)

        if buffer.count == configuration.maximumQueueSize {
            explicitTick.yield()
        }
    }

    func run() async throws {
        let timerSequence = AsyncTimerSequence(interval: configuration.scheduleDelay, clock: clock).map { _ in }
        let mergedSequence = merge(timerSequence, explicitTickStream).cancelOnGracefulShutdown()

        await withTaskGroup { taskGroup in
            taskGroup.addTask {
                for await log in self.logStream.cancelOnGracefulShutdown() {
                    await self._onLog(log)
                }
            }
            for await _ in mergedSequence where !(self.buffer.isEmpty) {
                await self.tick()
            }
            self.logger.debug("Shutting down.")
            try? await self.forceFlush()
            await self.exporter.shutdown()
            self.logger.debug("Shut down.")
            await taskGroup.waitForAll()
        }
    }

    func forceFlush() async throws {
        let chunkSize = Int(configuration.maximumExportBatchSize)
        let batches = stride(from: 0, to: buffer.count, by: chunkSize).map {
            buffer[$0 ..< min($0 + Int(configuration.maximumExportBatchSize), buffer.count)]
        }

        if !buffer.isEmpty {
            buffer.removeAll()

            try await withThrowingTaskGroup(of: Void.self) { group in
                for batch in batches {
                    group.addTask { await self.export(batch) }
                }

                group.addTask {
                    try await Task.sleep(for: self.configuration.exportTimeout, clock: self.clock)
                    throw CancellationError()
                }

                defer { group.cancelAll() }
                // Don't cancel unless it's an error
                // A single export shouldn't cancel the other exports
                try await group.next()
            }
        }

        try await exporter.forceFlush()
    }

    private func tick() async {
        let batch = buffer.prefix(Int(configuration.maximumExportBatchSize))
        buffer.removeFirst(batch.count)

        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { await self.export(batch) }
            group.addTask {
                try await Task.sleep(for: self.configuration.exportTimeout, clock: self.clock)
                throw CancellationError()
            }

            try? await group.next()
            group.cancelAll()
        }
    }

    private func export(_ batch: some Collection<OTelLogRecord> & Sendable) async {
        try? await exporter.export(batch)
    }
}

extension OTelBatchLogRecordProcessor where Clock == ContinuousClock {
    /// Create a batch log processor exporting log batches via the given log exporter.
    ///
    /// - Parameters:
    ///   - exporter: The log exporter to receive batched logs to export.
    ///   - configuration: Further configuration parameters to tweak the batching behavior.
    init(exporter: Exporter, configuration: OTelBatchLogRecordProcessorConfiguration, logger: Logger) {
        self.init(exporter: exporter, configuration: configuration, logger: logger, clock: .continuous)
    }
}

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

import AsyncAlgorithms
import DequeModule
import Logging
import ServiceLifecycle

/// A log processor that batches logs and forwards them to a configured exporter.
///
/// [OpenTelemetry Specification: Batching processor](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/logs/sdk.md#batching-processor)
@_spi(Logging)
public actor OTelBatchLogRecordProcessor<Exporter: OTelLogRecordExporter, Clock: _Concurrency.Clock>:
    OTelLogRecordProcessor,
    Service,
    CustomStringConvertible
where Clock.Duration == Duration
{
    public nonisolated let description = "OTelBatchLogEntryProcessor"

    internal /* for testing */ private(set) var buffer: Deque<OTelLogRecord>

    private let exporter: Exporter
    private let configuration: OTelBatchLogEntryProcessorConfiguration
    private let clock: Clock
    private let logStream: AsyncStream<OTelLogRecord>
    private let logContinuation: AsyncStream<OTelLogRecord>.Continuation
    private let explicitTickStream: AsyncStream<Void>
    private let explicitTick: AsyncStream<Void>.Continuation

    @_spi(Testing)
    public init(exporter: Exporter, configuration: OTelBatchLogEntryProcessorConfiguration, clock: Clock) {
        self.exporter = exporter
        self.configuration = configuration
        self.clock = clock

        buffer = Deque(minimumCapacity: Int(configuration.maximumQueueSize))
        (explicitTickStream, explicitTick) = AsyncStream.makeStream()
        (logStream, logContinuation) = AsyncStream.makeStream()
    }

    nonisolated public func onEmit(_ record: inout OTelLogRecord) {
        logContinuation.yield(record)
    }

    private func _onLog(_ log: OTelLogRecord) {
        buffer.append(log)

        if self.buffer.count == self.configuration.maximumQueueSize {
            self.explicitTick.yield()
        }
    }

    public func run() async throws {
        let timerSequence = AsyncTimerSequence(interval: configuration.scheduleDelay, clock: clock).map { _ in }
        let mergedSequence = merge(timerSequence, explicitTickStream).cancelOnGracefulShutdown()

        await withThrowingTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask {
                for await log in self.logStream {
                    await self._onLog(log)
                }
            }

            taskGroup.addTask {
                for try await _ in mergedSequence where !(await self.buffer.isEmpty) {
                    await self.tick()
                }
            }

            try? await taskGroup.next()
            taskGroup.cancelAll()
        }

        try? await forceFlush()
        await exporter.shutdown()
    }

    public func forceFlush() async throws {
        let chunkSize = Int(configuration.maximumExportBatchSize)
        let batches = stride(from: 0, to: buffer.count, by: chunkSize).map {
            buffer[$0 ..< min($0 + Int(configuration.maximumExportBatchSize), buffer.count)]
        }

        if !buffer.isEmpty {
            buffer.removeAll()

            await withThrowingTaskGroup(of: Void.self) { group in
                for batch in batches {
                    group.addTask { await self.export(batch) }
                }

                group.addTask {
                    try await Task.sleep(for: self.configuration.exportTimeout, clock: self.clock)
                    throw CancellationError()
                }

                try? await group.next()
                group.cancelAll()
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
        do {
            try await exporter.export(batch)
        } catch is CancellationError {
            // No-op
        } catch {
            // TODO: Should we emit this error somewhere?
        }
    }
}

@_spi(Logging)
extension OTelBatchLogRecordProcessor where Clock == ContinuousClock {
    /// Create a batch log processor exporting log batches via the given log exporter.
    ///
    /// - Parameters:
    ///   - exporter: The log exporter to receive batched logs to export.
    ///   - configuration: Further configuration parameters to tweak the batching behavior.
    public init(exporter: Exporter, configuration: OTelBatchLogEntryProcessorConfiguration) {
        self.init(exporter: exporter, configuration: configuration, clock: .continuous)
    }
}

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
            await withGracefulShutdownHandler {
                taskGroup.addTask {
                    self.logger.debug("Consuming from log stream.")
                    for await log in self.logStream {
                        await self._onLog(log)
                        self.logger.trace("Consumed log from stream.")
                    }
                    self.logger.debug("Log stream finished.")
                }
                for await _ in mergedSequence where !(self.buffer.isEmpty) {
                    await self.tick()
                }
                await taskGroup.waitForAll()
            } onGracefulShutdown: {
                self.logger.debug("Shutting down.")
                self.logContinuation.finish()
                self.explicitTick.finish()
            }
            try? await self.forceFlush()
            await self.exporter.shutdown()
            self.logger.debug("Shut down.")
        }
    }

    func forceFlush() async throws {
        guard !buffer.isEmpty else {
            logger.debug("Skipping force flush: buffer is empty")
            return
        }
        try await withTimeout(configuration.exportTimeout, clock: clock) {
            await withTaskGroup { group in
                var buffer = self.buffer
                while !buffer.isEmpty {
                    let batch = buffer.prefix(Int(self.configuration.maximumExportBatchSize))
                    group.addTask {
                        do {
                            try await self.exporter.export(batch)
                        } catch {
                            self.logger.error("Exporting batch failed", metadata: ["error": "\(error)"])
                        }
                    }
                    buffer.removeFirst(batch.count)
                }
                await group.waitForAll()
                do {
                    try await self.exporter.forceFlush()
                } catch {
                    self.logger.error("Force flush failed", metadata: ["error": "\(error)"])
                }
            }
        }
    }

    private func tick() async {
        let batch = buffer.prefix(Int(configuration.maximumExportBatchSize))
        buffer.removeFirst(batch.count)
        do {
            try await withTimeout(configuration.exportTimeout, clock: clock) {
                try await self.exporter.export(batch)
            }
        } catch {
            logger.warning("Export failed", metadata: ["error": "\(error)"])
        }
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

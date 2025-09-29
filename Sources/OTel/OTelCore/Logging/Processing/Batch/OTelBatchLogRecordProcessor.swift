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
    internal /* for testing */ private(set) var droppedCount = 0

    private let exporter: Exporter
    private let configuration: OTel.Configuration.LogsConfiguration.BatchLogRecordProcessorConfiguration
    private let clock: Clock
    private let logger: Logger
    private let logStream: AsyncStream<OTelLogRecord>
    private let logContinuation: AsyncStream<OTelLogRecord>.Continuation
    private let explicitTickStream: AsyncStream<Void>
    private let explicitTick: AsyncStream<Void>.Continuation
    private var batchID: UInt = 0

    init(exporter: Exporter, configuration: OTel.Configuration.LogsConfiguration.BatchLogRecordProcessorConfiguration, logger: Logger, clock: Clock) {
        self.logger = logger.withMetadata(component: "OTelBatchLogRecordProcessor")
        self.exporter = exporter
        self.configuration = configuration
        self.clock = clock

        buffer = Deque(minimumCapacity: configuration.maxQueueSize)
        (explicitTickStream, explicitTick) = AsyncStream.makeStream()
        (logStream, logContinuation) = AsyncStream.makeStream()
    }

    nonisolated func onEmit(_ record: inout OTelLogRecord) {
        logContinuation.yield(record)
    }

    private func _onLog(_ log: OTelLogRecord) {
        /// > - maxQueueSize - the maximum queue size. After the size is reached spans are dropped.
        ///
        /// — source: https://opentelemetry.io/docs/specs/otel/logs/sdk/#batching-processor
        guard buffer.count < configuration.maxQueueSize else {
            droppedCount += 1
            return
        }
        buffer.append(log)
        // NOTE: Unlike the BatchSpanProcessor, the spec does _not_ say the BatchLogRecordProcessor should trigger an
        // export when the queue size is reached.
    }

    func run() async throws {
        logger.debug("Starting.")
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
        logger.debug("Force flushing.", metadata: ["buffer_size": "\(buffer.count)"])
        try await withTimeout(configuration.exportTimeout, clock: clock) {
            await withTaskGroup { group in
                var buffer = self.buffer
                while !buffer.isEmpty {
                    let batch = buffer.prefix(self.configuration.maxExportBatchSize)
                    buffer.removeFirst(batch.count)
                    group.addTask { await self.export(batch) }
                }
                await group.waitForAll()
                do {
                    try await self.exporter.forceFlush()
                } catch {
                    self.logger.log(level: .warning, error: error, message: "Force flush failed.")
                }
            }
        }
    }

    private func tick() async {
        if droppedCount > 0 {
            logger.warning("Log records were dropped this iteration because queue was full", metadata: [
                "queue_size": "\(configuration.maxQueueSize)",
                "dropped_count": "\(droppedCount)",
            ])
            droppedCount = 0
        }
        let batch = buffer.prefix(configuration.maxExportBatchSize)
        buffer.removeFirst(batch.count)
        await export(batch)
    }

    private func export(_ batch: some Collection<OTelLogRecord> & Sendable) async {
        let batchID = batchID
        self.batchID += 1

        var logger = logger
        logger[metadataKey: "batch_id"] = "\(batchID)"
        logger[metadataKey: "batch_size"] = "\(batch.count)"

        do {
            try await withTimeout(configuration.exportTimeout, clock: clock) {
                try await self.exporter.export(batch)
                logger.debug("Exported batch.")
            }
        } catch {
            logger.log(level: .warning, error: error, message: "Failed to export batch.")
        }
    }
}

extension OTelBatchLogRecordProcessor where Clock == ContinuousClock {
    /// Create a batch log processor exporting log batches via the given log exporter.
    ///
    /// - Parameters:
    ///   - exporter: The log exporter to receive batched logs to export.
    ///   - configuration: Further configuration parameters to tweak the batching behavior.
    init(exporter: Exporter, configuration: OTel.Configuration.LogsConfiguration.BatchLogRecordProcessorConfiguration, logger: Logger) {
        self.init(exporter: exporter, configuration: configuration, logger: logger, clock: .continuous)
    }
}

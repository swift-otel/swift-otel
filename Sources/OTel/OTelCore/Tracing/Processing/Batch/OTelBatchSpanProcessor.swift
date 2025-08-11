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

/// A span processor that batches finished spans and forwards them to a configured exporter.
///
/// [OpenTelemetry Specification: Batching processor](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/trace/sdk.md#batching-processor)
actor OTelBatchSpanProcessor<Exporter: OTelSpanExporter, Clock: _Concurrency.Clock>:
    OTelSpanProcessor,
    Service,
    CustomStringConvertible
    where Clock.Duration == Duration
{
    nonisolated let description = "OTelBatchSpanProcessor"

    internal /* for testing */ private(set) var buffer: Deque<OTelFinishedSpan>
    internal /* for testing */ private(set) var droppedCount = 0

    private let logger: Logger
    private let exporter: Exporter
    private let configuration: OTelBatchSpanProcessorConfiguration
    private let clock: Clock
    private let spanStream: AsyncStream<OTelFinishedSpan>
    private let spanContinuation: AsyncStream<OTelFinishedSpan>.Continuation
    private let explicitTickStream: AsyncStream<Void>
    private let explicitTick: AsyncStream<Void>.Continuation
    private var batchID: UInt = 0

    init(exporter: Exporter, configuration: OTelBatchSpanProcessorConfiguration, logger: Logger, clock: Clock) {
        self.logger = logger.withMetadata(component: "OTelBatchSpanProcessor")
        self.exporter = exporter
        self.configuration = configuration
        self.clock = clock

        buffer = Deque(minimumCapacity: Int(configuration.maximumQueueSize))
        (explicitTickStream, explicitTick) = AsyncStream.makeStream()
        (spanStream, spanContinuation) = AsyncStream.makeStream()
    }

    nonisolated func onEnd(_ span: OTelFinishedSpan) {
        spanContinuation.yield(span)
    }

    func _onSpan(_ span: OTelFinishedSpan) {
        guard span.spanContext.traceFlags.contains(.sampled) else { return }
        /// > - maxQueueSize - the maximum queue size. After the size is reached spans are dropped.
        ///
        /// — source: https://opentelemetry.io/docs/specs/otel/logs/sdk/#batching-processor
        guard buffer.count < configuration.maximumQueueSize else {
            droppedCount += 1
            return
        }
        buffer.append(span)

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
                    self.logger.debug("Consuming from span stream.")
                    for await log in self.spanStream {
                        await self._onSpan(log)
                        self.logger.trace("Consumed span from stream.")
                    }
                    self.logger.debug("Span stream finished.")
                }
                for await _ in mergedSequence where !(self.buffer.isEmpty) {
                    await self.tick()
                }
                await taskGroup.waitForAll()
            } onGracefulShutdown: {
                self.logger.debug("Shutting down.")
                self.spanContinuation.finish()
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
        logger.info("Force flushing.", metadata: ["buffer_size": "\(buffer.count)"])
        try await withTimeout(configuration.exportTimeout, clock: clock) {
            await withTaskGroup { group in
                var buffer = self.buffer
                while !buffer.isEmpty {
                    let batch = buffer.prefix(Int(self.configuration.maximumExportBatchSize))
                    buffer.removeFirst(batch.count)
                    group.addTask { await self.export(batch) }
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
        if droppedCount > 0 {
            logger.warning("Spans were dropped this iteration because queue was full", metadata: [
                "queue_size": "\(configuration.maximumQueueSize)",
                "dropped_count": "\(droppedCount)",
            ])
            droppedCount = 0
        }
        let batch = buffer.prefix(Int(configuration.maximumExportBatchSize))
        buffer.removeFirst(batch.count)
        await export(batch)
    }

    private func export(_ batch: some Collection<OTelFinishedSpan> & Sendable) async {
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
            logger.warning("Failed to export batch.", metadata: [
                "error": "\(String(describing: type(of: error)))",
                "error_description": "\(error)",
            ])
        }
    }
}

extension OTelBatchSpanProcessor where Clock == ContinuousClock {
    /// Create a batch span processor exporting span batches via the given span exporter.
    ///
    /// - Parameters:
    ///   - exporter: The span exporter to receive batched spans to export.
    ///   - configuration: Further configuration parameters to tweak the batching behavior.
    init(exporter: Exporter, configuration: OTelBatchSpanProcessorConfiguration, logger: Logger) {
        self.init(exporter: exporter, configuration: configuration, logger: logger, clock: .continuous)
    }
}

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
public actor OTelBatchSpanProcessor<Exporter: OTelSpanExporter, Clock: _Concurrency.Clock>:
    OTelSpanProcessor,
    Service,
    CustomStringConvertible
    where Clock.Duration == Duration
{
    public nonisolated let description = "OTelBatchSpanProcessor"

    internal /* for testing */ private(set) var buffer: Deque<OTelFinishedSpan>

    private let logger = Logger(label: "OTelBatchSpanProcessor")
    private let exporter: Exporter
    private let configuration: OTelBatchSpanProcessorConfiguration
    private let clock: Clock
    private let explicitTickStream: AsyncStream<Void>
    private let explicitTick: AsyncStream<Void>.Continuation
    private var batchID: UInt = 0

    @_spi(Testing)
    public init(exporter: Exporter, configuration: OTelBatchSpanProcessorConfiguration, clock: Clock) {
        self.exporter = exporter
        self.configuration = configuration
        self.clock = clock

        buffer = Deque(minimumCapacity: Int(configuration.maximumQueueSize))
        (explicitTickStream, explicitTick) = AsyncStream.makeStream()
    }

    public func onEnd(_ span: OTelFinishedSpan) {
        guard span.spanContext.traceFlags.contains(.sampled) else { return }
        buffer.append(span)

        if buffer.count == configuration.maximumQueueSize {
            explicitTick.yield()
        }
    }

    public func run() async throws {
        let timerSequence = AsyncTimerSequence(interval: configuration.scheduleDelay, clock: clock).map { _ in }
        let mergedSequence = merge(timerSequence, explicitTickStream).cancelOnGracefulShutdown()

        for try await _ in mergedSequence where !buffer.isEmpty {
            await tick()
        }

        logger.debug("Shutting down.")
        try? await forceFlush()
        await exporter.shutdown()
        logger.debug("Shut down.")
    }

    public func forceFlush() async throws {
        let chunkSize = Int(configuration.maximumExportBatchSize)
        let batches = stride(from: 0, to: buffer.count, by: chunkSize).map {
            buffer[$0 ..< min($0 + Int(configuration.maximumExportBatchSize), buffer.count)]
        }

        if !buffer.isEmpty {
            logger.debug("Force flushing spans.", metadata: ["buffer_size": "\(buffer.count)"])

            buffer.removeAll()

            await withThrowingTaskGroup(of: Void.self) { group in
                for batch in batches {
                    group.addTask { await self.export(batch) }
                }

                group.addTask {
                    try await Task.sleep(for: self.configuration.exportTimeout, clock: self.clock)
                    self.logger.debug("Force flush timed out.")
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

    private func export(_ batch: some Collection<OTelFinishedSpan> & Sendable) async {
        let batchID = batchID
        self.batchID += 1

        var exportLogger = logger
        exportLogger[metadataKey: "batch_id"] = "\(batchID)"
        exportLogger.trace("Export batch.", metadata: ["batch_size": "\(batch.count)"])

        do {
            try await exporter.export(batch)
            exportLogger.trace("Exported batch.")
        } catch is CancellationError {
            exportLogger.debug("Export timed out.")
        } catch {
            exportLogger.debug("Failed to export batch.", metadata: [
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
    public init(exporter: Exporter, configuration: OTelBatchSpanProcessorConfiguration) {
        self.init(exporter: exporter, configuration: configuration, clock: .continuous)
    }
}

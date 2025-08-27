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

import Logging
import ServiceContextModule
import ServiceLifecycle

/// A span processor that simply forwards finished spans to a configured exporter, one at a time as soon as their ended.
///
/// - Warning: It is not recommended to use ``OTelSimpleSpanProcessor`` in production
/// since it will lead to an unnecessary amount of network calls within the exporter. Instead it is recommended
/// to use a batching span processor such as ``OTelBatchSpanProcessor`` that will forward multiple spans
/// to the exporter at once.
struct OTelSimpleSpanProcessor<Exporter: OTelSpanExporter>: OTelSpanProcessor {
    private let exporter: Exporter
    private let stream: AsyncStream<OTelFinishedSpan>
    private let continuation: AsyncStream<OTelFinishedSpan>.Continuation
    private let logger: Logger

    /// Create a span processor immediately forwarding spans to the given exporter.
    ///
    /// - Parameter exporter: The exporter to receive finished spans.
    /// On processor shutdown this exporter will also automatically be shut down.
    init(exporter: Exporter, logger: Logger) {
        self.logger = logger.withMetadata(component: "OTelSimpleSpanProcessor")
        self.exporter = exporter
        (stream, continuation) = AsyncStream.makeStream()
    }

    func run() async throws {
        logger.info("Starting.")
        await withGracefulShutdownHandler {
            for await span in stream {
                do {
                    logger.trace("Received ended span.", metadata: ["span_id": "\(span.spanContext.spanID)"])
                    try await exporter.export([span])
                } catch {
                    logger.log(level: .warning, error: error, message: "Failed to export log record.")
                    // simple log processor does not attempt retries
                }
            }
        } onGracefulShutdown: {
            logger.info("Shutting down.")
            continuation.finish()
        }
        await exporter.shutdown()
        logger.info("Shut down.")
    }

    func onStart(_ span: OTelSpan, parentContext: ServiceContext) {
        // no-op
    }

    func onEnd(_ span: OTelFinishedSpan) {
        guard span.spanContext.traceFlags.contains(.sampled) else { return }
        continuation.yield(span)
    }

    func forceFlush() async throws {
        try await exporter.forceFlush()
    }
}

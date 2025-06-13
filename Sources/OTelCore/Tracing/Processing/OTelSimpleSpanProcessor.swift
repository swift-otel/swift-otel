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

/// A span processor that simply forwards finished spans to a configured exporter, one at a time as soon as their ended.
///
/// - Warning: It is not recommended to use ``OTelSimpleSpanProcessor`` in production
/// since it will lead to an unnecessary amount of network calls within the exporter. Instead it is recommended
/// to use a batching span processor such as ``OTelBatchSpanProcessor`` that will forward multiple spans
/// to the exporter at once.
public struct OTelSimpleSpanProcessor<Exporter: OTelSpanExporter>: OTelSpanProcessor {
    private let exporter: Exporter
    private let stream: AsyncStream<OTelFinishedSpan>
    private let continuation: AsyncStream<OTelFinishedSpan>.Continuation
    private let logger = Logger(label: "OTelSimpleSpanProcessor")

    /// Create a span processor immediately forwarding spans to the given exporter.
    ///
    /// - Parameter exporter: The exporter to receive finished spans.
    /// On processor shutdown this exporter will also automatically be shut down.
    public init(exporter: Exporter) {
        self.exporter = exporter
        (stream, continuation) = AsyncStream.makeStream()
    }

    public func run() async throws {
        for try await span in stream.cancelOnGracefulShutdown() {
            do {
                logger.trace("Received ended span.", metadata: ["span_id": "\(span.spanContext.spanID)"])
                try await exporter.export([span])
            } catch {
                // simple span processor does not attempt retries, so this is no-op
            }
        }
    }

    public func onStart(_ span: OTelSpan, parentContext: ServiceContext) {
        // no-op
    }

    public func onEnd(_ span: OTelFinishedSpan) {
        guard span.spanContext.traceFlags.contains(.sampled) else { return }
        continuation.yield(span)
    }

    public func forceFlush() async throws {
        try await exporter.forceFlush()
    }

    public func shutdown() async throws {
        await exporter.shutdown()
    }
}

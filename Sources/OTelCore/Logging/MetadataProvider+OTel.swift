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

extension Logger.MetadataProvider {
    /// A metadata provider exposing the current trace and span ID.
    ///
    /// [OpenTelemetry Specification: Trace Context Fields](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/logs/data-model.md#trace-context-fields)
    ///
    /// - Parameters:
    ///   - traceIDKey: The metadata key of the trace ID. Defaults to `"trace_id"`.
    ///   - spanIDKey: The metadata key of the span ID. Defaults to `"span_id"`.
    ///   - traceFlagsKey: The metadata key of the trace flags. Defaults to `"trace_flags"`.
    ///   - parentSpanIDKey: The metadata key of the parent span ID. Defaults to `nil`, i.e. not included.
    /// - Returns: A metadata provider ready to use with Logging.
    public static func otel(
        traceIDKey: String = "trace_id",
        spanIDKey: String = "span_id",
        traceFlagsKey: String = "trace_flags",
        parentSpanIDKey: String? = nil
    ) -> Logger.MetadataProvider {
        .init {
            guard let spanContext = ServiceContext.current?.spanContext else { return [:] }
            var metadata: Logger.Metadata = [
                traceIDKey: "\(spanContext.traceID)",
                spanIDKey: "\(spanContext.spanID)",
                traceFlagsKey: "\(spanContext.traceFlags.rawValue)",
            ]
            if let parentSpanIDKey, let parentSpanID = spanContext.parentSpanID {
                metadata[parentSpanIDKey] = "\(parentSpanID)"
            }
            return metadata
        }
    }

    /// A metadata provider exposing the current trace and span ID.
    public static let otel = Logger.MetadataProvider.otel()
}

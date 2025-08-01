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

import W3CTraceContext

/// Represents the portion of an ``OTelSpan`` which must be serialized and propagated across asynchronous boundaries.
///
/// [OTel Spec: SpanContext](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/trace/api.md#spancontext)
struct OTelSpanContext: Hashable, Sendable {
    private var traceContext: TraceContext

    /// The ID of the trace the span belongs to.
    var traceID: TraceID {
        traceContext.traceID
    }

    /// The unique ID of this span.
    var spanID: SpanID {
        traceContext.spanID
    }

    /// An 8-bit field controlling tracing flags such as sampling.
    var traceFlags: TraceFlags {
        traceContext.flags
    }

    /// Additional vendor-specific trace identification information.
    var traceState: TraceState {
        get {
            traceContext.state
        }
        set {
            traceContext.state = newValue
        }
    }

    /// The unique ID of the span's parent or `nil` if it's the root span.
    let parentSpanID: SpanID?

    /// Whether this span context describes a span that originated on a different service.
    let isRemote: Bool

    var traceParentHeaderValue: String {
        traceContext.traceParentHeaderValue
    }

    var traceStateHeaderValue: String? {
        traceContext.traceStateHeaderValue
    }

    /// Create a local span context.
    ///
    /// - Parameters:
    ///   - traceID: The ID of the trace the span belongs to.
    ///   - spanID: The unique ID of this span.
    ///   - parentSpanID: The unique ID of the span's parent or nil if it’s the root span.
    ///   - traceFlags: An 8-bit field controlling tracing flags such as sampling.
    ///   - traceState: Additional vendor-specific trace identification information.
    /// - Returns: A span context describing a local span.
    static func local(
        traceID: TraceID,
        spanID: SpanID,
        parentSpanID: SpanID?,
        traceFlags: TraceFlags,
        traceState: TraceState
    ) -> OTelSpanContext {
        OTelSpanContext(
            traceContext: TraceContext(
                traceID: traceID,
                spanID: spanID,
                flags: traceFlags,
                state: traceState
            ),
            parentSpanID: parentSpanID,
            isRemote: false
        )
    }

    /// Create a remote span context from a deserialized W3C Trace Context.
    ///
    /// - Parameter traceContext: The W3C Trace Context describing the remote span.
    /// - Returns: A span context describing a remote span.
    static func remote(traceContext: TraceContext) -> OTelSpanContext {
        OTelSpanContext(traceContext: traceContext, parentSpanID: nil, isRemote: true)
    }

    private init(traceContext: TraceContext, parentSpanID: SpanID?, isRemote: Bool) {
        self.traceContext = traceContext
        self.parentSpanID = parentSpanID
        self.isRemote = isRemote
    }
}

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

import struct Foundation.Data
import OTLPCore
import Tracing
import W3CTraceContext

extension Opentelemetry_Proto_Trace_V1_Span {
    /// Create a span from an `OTelFinishedSpan`.
    ///
    /// - Parameter finishedSpan: The `OTelFinishedSpan` to cast.
    init(_ finishedSpan: OTelFinishedSpan) {
        self.init()
        traceID = finishedSpan.spanContext.traceID.data
        spanID = finishedSpan.spanContext.spanID.data

        if let traceStateHeaderValue = finishedSpan.spanContext.traceStateHeaderValue {
            self.traceState = traceStateHeaderValue
        }

        if let parentSpanID = finishedSpan.spanContext.parentSpanID {
            self.parentSpanID = parentSpanID.data
        }

        name = finishedSpan.operationName
        kind = .init(finishedSpan.kind)

        if let status = finishedSpan.status {
            self.status = .init(status)
        }

        startTimeUnixNano = finishedSpan.startTimeNanosecondsSinceEpoch
        endTimeUnixNano = finishedSpan.endTimeNanosecondsSinceEpoch

        attributes = .init(finishedSpan.attributes)
        events = finishedSpan.events.map(Opentelemetry_Proto_Trace_V1_Span.Event.init)
        links = finishedSpan.links.compactMap(Opentelemetry_Proto_Trace_V1_Span.Link.init)
    }
}

extension Opentelemetry_Proto_Trace_V1_ResourceSpans {
    init(_ finishedSpans: some Collection<OTelFinishedSpan>) {
        self.init()
        if let resource = finishedSpans.first?.resource {
            self.resource = .init(resource)
        }

        self.scopeSpans = [Opentelemetry_Proto_Trace_V1_ScopeSpans.with {
            $0.scope = .swiftOTelScope
            $0.spans = finishedSpans.map(Opentelemetry_Proto_Trace_V1_Span.init)
        }]
    }
}

extension Opentelemetry_Proto_Common_V1_InstrumentationScope {
    fileprivate static let swiftOTelScope = Opentelemetry_Proto_Common_V1_InstrumentationScope.with {
        $0.name = "swift-otel"
        $0.version = OTelLibrary.version
    }
}

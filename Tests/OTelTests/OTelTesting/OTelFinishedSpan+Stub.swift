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

import Tracing
import W3CTraceContext

@testable import OTel

extension OTelFinishedSpan {
    /// A finished span stub.
    ///
    /// - Parameters:
    ///   - traceID: Defaults to `OTelTraceID.allZeroes`.
    ///   - spanID: Defaults to `OTelSpanID.allZeroes`.
    ///   - parentSpanID: Defaults to `nil.`
    ///   - traceFlags: Defaults to no flags.
    ///   - traceState: Defaults to `nil`.
    ///   - isRemote: Defaults to `false`.
    ///   - operationName: Defaults to an empty string.
    ///   - kind: Defaults to `.internal`.
    ///   - status: Defaults to `nil`.
    ///   - startTimeNanosecondsSinceEpoch: Defaults to `0`.
    ///   - endTimeNanosecondsSinceEpoch: Defaults to `0`,
    ///   - attributes: Defaults to no attributes.
    ///   - resource: Defaults to an empty resource.
    ///   - events: Defaults to no events.
    ///   - links: Defaults to no links.
    ///
    /// - Returns: A finished span stub.
    static func stub(
        traceID: TraceID = .allZeroes,
        spanID: SpanID = .allZeroes,
        parentSpanID: SpanID? = nil,
        traceFlags: TraceFlags = [],
        traceState: TraceState = TraceState(),
        isRemote: Bool = false,
        operationName: String = "",
        kind: SpanKind = .internal,
        status: SpanStatus? = nil,
        startTimeNanosecondsSinceEpoch: UInt64 = 0,
        endTimeNanosecondsSinceEpoch: UInt64 = 0,
        attributes: SpanAttributes = [:],
        resource: OTelResource = OTelResource(),
        events: [SpanEvent] = [],
        links: [SpanLink] = []
    ) -> OTelFinishedSpan {
        let spanContext: OTelSpanContext =
            if isRemote {
                .remote(
                    traceContext: TraceContext(
                        traceID: traceID,
                        spanID: spanID,
                        flags: traceFlags,
                        state: traceState
                    )
                )
            } else {
                .local(
                    traceID: traceID,
                    spanID: spanID,
                    parentSpanID: parentSpanID,
                    traceFlags: traceFlags,
                    traceState: traceState
                )
            }
        return OTelFinishedSpan(
            spanContext: spanContext,
            operationName: operationName,
            kind: kind,
            status: status,
            startTimeNanosecondsSinceEpoch: startTimeNanosecondsSinceEpoch,
            endTimeNanosecondsSinceEpoch: endTimeNanosecondsSinceEpoch,
            attributes: attributes,
            resource: resource,
            events: events,
            links: links
        )
    }
}

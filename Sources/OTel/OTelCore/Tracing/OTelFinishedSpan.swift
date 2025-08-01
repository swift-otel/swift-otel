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

/// A read-only representation of an ended ``OTelSpan``.
struct OTelFinishedSpan: Sendable {
    /// The context of this span.
    let spanContext: OTelSpanContext

    /// The spans operation name.
    let operationName: String

    /// The spans kind.
    let kind: SpanKind

    /// The spans status.
    let status: SpanStatus?

    /// The time when the span started in nanoseconds since epoch.
    let startTimeNanosecondsSinceEpoch: UInt64

    /// The time when the span ended in nanoseconds since epoch.
    let endTimeNanosecondsSinceEpoch: UInt64

    /// The attributes added to the span.
    let attributes: SpanAttributes

    /// The resource this span instrumented.
    let resource: OTelResource

    /// The events added to the span.
    let events: [SpanEvent]

    /// The links from this span to other spans.
    let links: [SpanLink]

    init(
        spanContext: OTelSpanContext,
        operationName: String,
        kind: SpanKind,
        status: SpanStatus?,
        startTimeNanosecondsSinceEpoch: UInt64,
        endTimeNanosecondsSinceEpoch: UInt64,
        attributes: SpanAttributes,
        resource: OTelResource,
        events: [SpanEvent],
        links: [SpanLink]
    ) {
        self.spanContext = spanContext
        self.operationName = operationName
        self.kind = kind
        self.status = status
        self.startTimeNanosecondsSinceEpoch = startTimeNanosecondsSinceEpoch
        self.endTimeNanosecondsSinceEpoch = endTimeNanosecondsSinceEpoch
        self.attributes = attributes
        self.resource = resource
        self.events = events
        self.links = links
    }
}

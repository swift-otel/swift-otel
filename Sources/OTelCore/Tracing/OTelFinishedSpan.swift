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
public struct OTelFinishedSpan: Sendable {
    /// The context of this span.
    public let spanContext: OTelSpanContext

    /// The spans operation name.
    public let operationName: String

    /// The spans kind.
    public let kind: SpanKind

    /// The spans status.
    public let status: SpanStatus?

    /// The time when the span started in nanoseconds since epoch.
    public let startTimeNanosecondsSinceEpoch: UInt64

    /// The time when the span ended in nanoseconds since epoch.
    public let endTimeNanosecondsSinceEpoch: UInt64

    /// The attributes added to the span.
    public let attributes: SpanAttributes

    /// The resource this span instrumented.
    public let resource: OTelResource

    /// The events added to the span.
    public let events: [SpanEvent]

    /// The links from this span to other spans.
    public let links: [SpanLink]

    public init(
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

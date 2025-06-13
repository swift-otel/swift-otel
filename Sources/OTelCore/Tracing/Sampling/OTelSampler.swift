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

/// Decides whether a given span should be sampled.
public protocol OTelSampler: Sendable {
    /// Request a sampling result for the given span values.
    ///
    /// - Note: The received values are all captured at the time of span creation.
    /// Most of these values _may_ change after a sampling decision was made.
    ///
    /// - Parameters:
    ///   - operationName: The span's operation name at time of creation.
    ///   - kind: The span's kind.
    ///   - traceID: The span's trace ID.
    ///   - attributes: The span's attributes at time of creation.
    ///   - links: The span's links at time of creation.
    ///   - parentContext: The span's parent service context.
    ///
    /// - Returns: A result indicating whether to sample the span.
    func samplingResult(
        operationName: String,
        kind: SpanKind,
        traceID: TraceID,
        attributes: SpanAttributes,
        links: [SpanLink],
        parentContext: ServiceContext
    ) -> OTelSamplingResult
}

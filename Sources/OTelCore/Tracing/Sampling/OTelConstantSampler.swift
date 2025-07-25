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

package import Tracing
package import W3CTraceContext

/// A sampler that always takes the same sampling decision.
package struct OTelConstantSampler: OTelSampler {
    private let decision: OTelSamplingResult.Decision

    /// Create a sampler that always takes the given decision.
    ///
    /// - Parameter decision: The decision to take.
    package init(decision: OTelSamplingResult.Decision) {
        self.decision = decision
    }

    /// Create a sampler that either always decides to
    /// ``OTelSamplingResult/Decision-swift.enum/recordAndSample`` or
    /// ``OTelSamplingResult/Decision-swift.enum/drop``
    /// based on the given boolean.
    ///
    /// - Parameter isOn: Whether to always decides to
    /// ``OTelSamplingResult/Decision-swift.enum/recordAndSample`` or
    /// ``OTelSamplingResult/Decision-swift.enum/drop``.
    package init(isOn: Bool) {
        decision = isOn ? .recordAndSample : .drop
    }

    package func samplingResult(
        operationName: String,
        kind: SpanKind,
        traceID: TraceID,
        attributes: SpanAttributes,
        links: [SpanLink],
        parentContext: ServiceContext
    ) -> OTelSamplingResult {
        OTelSamplingResult(decision: decision, attributes: [:])
    }
}

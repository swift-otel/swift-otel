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

/// An `OTelSampler` based on a given `TraceID` and `ratio`.
///
/// [OpenTelemetry Specification: TraceIDRatioBased Sampler](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/trace/sdk.md#traceidratiobased)
public struct OTelTraceIDRatioBasedSampler: OTelSampler, Equatable, Hashable, CustomStringConvertible {
    let idUpperBound: UInt64
    public let ratio: Double

    /// Create a trace id ratio based sampler with the given sampling `ratio`.
    ///
    /// - Parameter ratio: The sampling ratio. Must be between 0.0 and 1.0.
    public init(ratio: Double) {
        precondition(ratio >= 0.0 && ratio <= 1.0, "ratio must be between 0.0 and 1.0")

        self.ratio = ratio
        if ratio == 0.0 {
            idUpperBound = .min
        } else if ratio == 1.0 {
            idUpperBound = .max
        } else {
            idUpperBound = UInt64(ratio * Double(UInt64.max))
        }
    }

    public func samplingResult(
        operationName: String,
        kind: SpanKind,
        traceID: TraceID,
        attributes: SpanAttributes,
        links: [SpanLink],
        parentContext: ServiceContext
    ) -> OTelSamplingResult {
        if idUpperBound == .min {
            return .init(decision: .drop)
        } else if idUpperBound == .max {
            return .init(decision: .recordAndSample)
        }

        let value = traceID.bytes.withUnsafeBytes {
            assert($0.count == 16, "TraceID must be 16 bytes")
            return $0[8...].load(as: UInt64.self)
        }

        if value < idUpperBound {
            return .init(decision: .recordAndSample)
        } else {
            return .init(decision: .drop)
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.idUpperBound == rhs.idUpperBound
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(idUpperBound)
    }

    public var description: String {
        "TraceIdRatioBased{\(ratio)}"
    }
}

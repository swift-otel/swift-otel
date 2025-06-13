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

import Instrumentation
import W3CTraceContext

/// A propagator which operates on HTTP headers using the [W3C TraceContext](https://www.w3.org/TR/2020/REC-trace-context-1-20200206/).
public struct OTelW3CPropagator: OTelPropagator {
    private static let traceParentHeaderName = "traceparent"
    private static let traceStateHeaderName = "tracestate"
    private static let dash = UInt8(ascii: "-")

    /// Initialize a `W3CPropagator`.
    public init() {}

    public func extractSpanContext<Carrier, Extract>(
        from carrier: Carrier,
        using extractor: Extract
    ) throws -> OTelSpanContext? where Extract: Extractor, Carrier == Extract.Carrier {
        guard let traceParentHeaderValue = extractor.extract(key: Self.traceParentHeaderName, from: carrier) else {
            return nil
        }
        let traceStateHeaderValue = extractor.extract(key: Self.traceStateHeaderName, from: carrier)

        let traceContext = try TraceContext(
            traceParentHeaderValue: traceParentHeaderValue,
            traceStateHeaderValue: traceStateHeaderValue
        )
        return .remote(traceContext: traceContext)
    }

    public func inject<Carrier, Inject>(
        _ spanContext: OTelSpanContext,
        into carrier: inout Carrier,
        using injector: Inject
    ) where Inject: Injector, Carrier == Inject.Carrier {
        injector.inject(spanContext.traceParentHeaderValue, forKey: Self.traceParentHeaderName, into: &carrier)

        if let traceStateHeaderValue = spanContext.traceStateHeaderValue {
            injector.inject(traceStateHeaderValue, forKey: Self.traceStateHeaderName, into: &carrier)
        }
    }
}

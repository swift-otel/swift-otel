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

/// A pseudo-`OTelPropagator` that may be used to instrument using
/// multiple other `OTelPropagator`s across a common `OTelSpanContext`.
public struct OTelMultiplexPropagator: OTelPropagator {
    private let propagators: [OTelPropagator]

    /// Create a `MultiplexPropagator`.
    ///
    /// ## Extraction Priority
    ///
    /// The order of the given propagators matters when extracting!
    /// If multiple propagators successfully extract, the extracted span context of
    /// the last propagator called, i.e. the last propagator in the `propagators` array.
    ///
    /// - Parameter propagators: An array of `OTelPropagator`s, each of which
    /// will be used to `inject`/`extract` through the same `SpanContext`.
    public init(_ propagators: [OTelPropagator]) {
        self.propagators = propagators
    }

    public func extractSpanContext<Carrier, Extract>(
        from carrier: Carrier,
        using extractor: Extract
    ) throws -> OTelSpanContext? where Extract: Extractor, Carrier == Extract.Carrier {
        var spanContext: OTelSpanContext?
        for propagator in propagators {
            guard let context = try propagator.extractSpanContext(from: carrier, using: extractor) else {
                continue
            }
            spanContext = context
        }
        return spanContext
    }

    public func inject<Carrier, Inject>(
        _ spanContext: OTelSpanContext,
        into carrier: inout Carrier,
        using injector: Inject
    ) where Inject: Injector, Carrier == Inject.Carrier {
        propagators.forEach { $0.inject(spanContext, into: &carrier, using: injector) }
    }
}

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

/// A propagator carries span context over asynchronous boundaries such as HTTP calls.
public protocol OTelPropagator: Sendable {
    /// Try to extract a span context from the given carrier.
    ///
    /// - Parameters:
    ///   - carrier: The carrier which potentially contains a span context.
    ///   - extractor: The extractor used to extract values from the carrier.
    func extractSpanContext<Carrier, Extract>(
        from carrier: Carrier,
        using extractor: Extract
    ) throws -> OTelSpanContext? where Extract: Extractor, Extract.Carrier == Carrier

    /// Inject the given span context into the given carrier.
    ///
    /// - Parameters:
    ///   - spanContext: The span context to be injected.
    ///   - carrier: The carrier which to inject into.
    ///   - injector: The injector used to inject values into the carrier.
    func inject<Carrier, Inject>(
        _ spanContext: OTelSpanContext,
        into carrier: inout Carrier,
        using injector: Inject
    ) where Inject: Injector, Inject.Carrier == Carrier
}

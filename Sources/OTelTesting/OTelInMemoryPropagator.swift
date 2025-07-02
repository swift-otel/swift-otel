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

package import Instrumentation
import NIOConcurrencyHelpers
package import OTelCore

package final class OTelInMemoryPropagator: OTelPropagator, Sendable {
    private let _injectedSpanContexts = NIOLockedValueBox([OTelSpanContext]())
    package var injectedSpanContexts: [OTelSpanContext] { _injectedSpanContexts.withLockedValue { $0 } }

    private let _extractedCarriers = NIOLockedValueBox([any Sendable]())
    package var extractedCarriers: [any Sendable] { _extractedCarriers.withLockedValue { $0 } }
    private let extractionResult: Result<OTelSpanContext, Error>?

    package init(extractionResult: Result<OTelSpanContext, Error>? = nil) {
        self.extractionResult = extractionResult
    }

    package func inject<Carrier, Inject>(
        _ spanContext: OTelSpanContext,
        into carrier: inout Carrier,
        using injector: Inject
    ) where Carrier == Inject.Carrier, Inject: Injector {
        _injectedSpanContexts.withLockedValue { $0.append(spanContext) }
    }

    package func extractSpanContext<Carrier, Extract>(
        from carrier: Carrier,
        using extractor: Extract
    ) throws -> OTelSpanContext? where Carrier == Extract.Carrier, Extract: Extractor {
        _extractedCarriers.withLockedValue { $0.append(carrier) }
        switch extractionResult {
        case .success(let spanContext): return spanContext
        case .failure(let error): throw error
        case nil: return nil
        }
    }
}

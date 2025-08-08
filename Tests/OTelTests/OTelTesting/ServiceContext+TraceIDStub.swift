//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2025 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import OTel
import ServiceContextModule
import W3CTraceContext

extension ServiceContext {
    /// A top-level service context with a span context containing the given trace ID.
    ///
    /// - Parameter value: The trace ID to store inside the service context's span context.
    /// - Returns: A top-level service context with `traceID` stored in the span context.
    static func withTraceID(_ traceID: TraceID) -> ServiceContext {
        var context = ServiceContext.topLevel
        context.spanContext = .localStub(traceID: traceID)
        return context
    }
}

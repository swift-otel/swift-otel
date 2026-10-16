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

import Instrumentation
@testable import OTel
import W3CTraceContext

extension InstrumentationContext {
    /// A top-level instrumentation context with a span context containing the given trace ID.
    ///
    /// - Parameter value: The trace ID to store inside the instrumentation context's span context.
    /// - Returns: A top-level instrumentation context with `traceID` stored in the span context.
    static func withTraceID(_ traceID: TraceID) -> InstrumentationContext {
        var context = InstrumentationContext.topLevel
        context.spanContext = .localStub(traceID: traceID)
        return context
    }

    /// A top-level instrumentation context with a span context using the given trace flags.
    ///
    /// - Parameter traceFlags: The trace flags to store inside the instrumentation context's span context.
    /// - Returns: A top-level instrumentation context with a span context using `traceFlags`.
    static func withTraceFlags(_ traceFlags: TraceFlags) -> InstrumentationContext {
        var context = InstrumentationContext.topLevel
        context.spanContext = .localStub(traceFlags: traceFlags)
        return context
    }
}

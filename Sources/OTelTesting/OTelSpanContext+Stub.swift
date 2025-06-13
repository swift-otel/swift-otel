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

import OTelCore
import W3CTraceContext

extension OTelSpanContext {
    /// A local span context stub.
    ///
    /// - Parameters:
    ///   - traceID: Defaults to `OTelTraceID.allZeroes`.
    ///   - spanID: Defaults to `OTelSpanID.allZeroes`.
    ///   - parentSpanID: Defaults to `nil`.
    ///   - traceFlags: Defaults to no flags.
    ///   - traceState: Defaults to no trace state.
    ///
    /// - Returns: A span context stub.
    package static func localStub(
        traceID: TraceID = .allZeroes,
        spanID: SpanID = .allZeroes,
        parentSpanID: SpanID? = nil,
        traceFlags: TraceFlags = [],
        traceState: TraceState = TraceState()
    ) -> OTelSpanContext {
        .local(
            traceID: traceID,
            spanID: spanID,
            parentSpanID: parentSpanID,
            traceFlags: traceFlags,
            traceState: traceState
        )
    }

    /// A local span context stub.
    ///
    /// - Parameters:
    ///   - traceID: Defaults to `OTelTraceID.allZeroes`.
    ///   - spanID: Defaults to `OTelSpanID.allZeroes`.
    ///   - traceFlags: Defaults to no flags.
    ///   - traceState: Defaults to no trace state.
    ///
    /// - Returns: A span context stub.
    package static func remoteStub(
        traceID: TraceID = .allZeroes,
        spanID: SpanID = .allZeroes,
        traceFlags: TraceFlags = [],
        traceState: TraceState = TraceState()
    ) -> OTelSpanContext {
        .remote(traceContext: TraceContext(traceID: traceID, spanID: spanID, flags: traceFlags, state: traceState))
    }
}

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

import ServiceContextModule
import Tracing

@testable import OTel

extension OTelSpan {
    /// A no-op span stub.
    ///
    /// - Parameter context: Defaults to `ServiceContext.topLevel`.
    ///
    /// - Returns: A no-op span stub.
    static func noOpStub(context: ServiceContext = .topLevel) -> OTelSpan {
        .noOp(.init(context: context))
    }

    /// A recording span stub.
    ///
    /// - Parameters:
    ///   - operationName: Defaults to "test".
    ///   - kind: Defaults to `SpanKind.internal`.
    ///   - context: Defaults to `ServiceContext.topLevel`.
    ///   - spanContext: Defaults to ``OTel/OTelSpanContext/localStub(traceID:spanID:parentSpanID:traceFlags:traceState)``
    ///   - attributes: Defaults to no attributes.
    ///   - startTimeNanosecondsSinceEpoch: Defaults to `0`.
    ///   - onEnd: Defaults to a no-op closure.
    ///
    /// - Returns: A recording span stub.
    static func recordingStub(
        operationName: String = "test",
        kind: SpanKind = .internal,
        context: ServiceContext = .topLevel,
        spanContext: OTelSpanContext = .localStub(),
        attributes: SpanAttributes = [:],
        startTimeNanosecondsSinceEpoch: UInt64 = 0,
        onEnd: @escaping @Sendable (OTelRecordingSpan, _ endTimeNanosecondsSinceEpoch: UInt64) -> Void = { _, _ in }
    ) -> OTelSpan {
        .recording(
            operationName: operationName,
            kind: kind,
            context: context,
            spanContext: spanContext,
            attributes: attributes,
            startTimeNanosecondsSinceEpoch: startTimeNanosecondsSinceEpoch,
            onEnd: onEnd
        )
    }
}

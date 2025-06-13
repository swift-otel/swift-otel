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

import W3CTraceContext

/// An ID generator generates random trace and span IDs on demand.
///
/// [OpenTelemetry Specification: ID generators](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/trace/sdk.md#id-generators)
public protocol OTelIDGenerator: Sendable {
    /// Get a generated trace ID.
    ///
    /// - Returns: A generated trace ID.
    func nextTraceID() -> TraceID

    /// Get a generated span ID.
    ///
    /// - Returns: A generated span ID.
    func nextSpanID() -> SpanID
}

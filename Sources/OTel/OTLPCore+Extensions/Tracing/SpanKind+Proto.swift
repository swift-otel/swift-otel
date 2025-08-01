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

#if !(OTLPHTTP || OTLPGRPC)
// Empty when above trait(s) are disabled.
#else
import OTLPCore
import Tracing

extension Opentelemetry_Proto_Trace_V1_Span.SpanKind {
    /// Create a span kind from a `SpanKind`.
    ///
    /// - Parameter kind: The `SpanKind` to cast.
    init(_ kind: SpanKind) {
        switch kind {
        case .server:
            self = .server
        case .client:
            self = .client
        case .producer:
            self = .producer
        case .consumer:
            self = .consumer
        case .internal:
            self = .internal
        }
    }
}
#endif

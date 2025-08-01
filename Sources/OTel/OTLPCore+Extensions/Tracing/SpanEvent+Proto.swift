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

extension Opentelemetry_Proto_Trace_V1_Span.Event {
    /// Create an event from a `SpanEvent`.
    ///
    /// - Parameter event: The `SpanEvent` to cast.
    init(_ event: SpanEvent) {
        self.init()
        name = event.name
        timeUnixNano = event.nanosecondsSinceEpoch
        attributes = .init(event.attributes)
    }
}
#endif

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
import OTel // NOTE: Not @testable import, to test public API visibility.
import Testing
import W3CTraceContext

@Suite
struct InstrumentationContextPublicAPITests {
    @Test("Trace ID set to nil without span context")
    func traceIDNil() throws {
        let context = InstrumentationContext.topLevel

        #expect(context.otelTraceID == nil)
    }

    @Test("Span context's trace ID exposed")
    func traceIDNotNil() {
        let context = InstrumentationContext.withTraceID(.oneToSixteen)

        #expect(context.otelTraceID == "0102030405060708090a0b0c0d0e0f10")
    }

    @Test("Not sampled without span context")
    func isSampledWithoutSpanContext() {
        let context = InstrumentationContext.topLevel

        #expect(context.otelIsSampled == false)
    }

    @Test("Not sampled when sampled flag not set")
    func isSampledFalse() {
        let context = InstrumentationContext.withTraceFlags([])

        #expect(context.otelIsSampled == false)
    }

    @Test("Sampled when sampled flag set")
    func isSampledTrue() {
        let context = InstrumentationContext.withTraceFlags(.sampled)

        #expect(context.otelIsSampled == true)
    }
}

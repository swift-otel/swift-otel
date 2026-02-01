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

import OTel  // NOTE: Not @testable import, to test public API visibility.
import ServiceContextModule
import Testing
import W3CTraceContext

@Suite
struct ServiceContextPublicAPITests {
    @Test("Trace ID set to nil without span context")
    func traceIDNil() throws {
        let context = ServiceContext.topLevel

        #expect(context.otelTraceID == nil)
    }

    @Test("Span context's trace ID exposed")
    func traceIDNotNil() {
        let context = ServiceContext.withTraceID(.oneToSixteen)

        #expect(context.otelTraceID == "0102030405060708090a0b0c0d0e0f10")
    }
}

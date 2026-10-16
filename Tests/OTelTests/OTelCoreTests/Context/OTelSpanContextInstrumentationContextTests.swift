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

import Instrumentation
@testable import OTel
import Testing

@Suite
struct OTelSpanContextInstrumentationContextTests {
    @Test
    func spanContext_storedInsideInstrumentationContext() {
        let spanContext = OTelSpanContext.localStub()

        var instrumentationContext = InstrumentationContext.topLevel
        #expect(instrumentationContext.isEmpty)
        #expect(instrumentationContext.spanContext == nil)

        instrumentationContext.spanContext = spanContext
        #expect(instrumentationContext.count == 1)

        #expect(instrumentationContext.spanContext == spanContext)
    }
}

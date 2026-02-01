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
import Testing

@testable import OTel

@Suite
struct OTelSpanContextServiceContextTests {
    @Test
    func spanContext_storedInsideServiceContext() {
        let spanContext = OTelSpanContext.localStub()

        var serviceContext = ServiceContext.topLevel
        #expect(serviceContext.isEmpty)
        #expect(serviceContext.spanContext == nil)

        serviceContext.spanContext = spanContext
        #expect(serviceContext.count == 1)

        #expect(serviceContext.spanContext == spanContext)
    }
}

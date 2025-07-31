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

@testable import OTelCore
import OTelTesting
import ServiceContextModule
import XCTest

final class OTelSpanContextServiceContextTests: XCTestCase {
    func test_spanContext_storedInsideServiceContext() {
        let spanContext = OTelSpanContext.localStub()

        var serviceContext = ServiceContext.topLevel
        XCTAssertTrue(serviceContext.isEmpty)
        XCTAssertNil(serviceContext.spanContext)

        serviceContext.spanContext = spanContext
        XCTAssertEqual(serviceContext.count, 1)

        XCTAssertEqual(serviceContext.spanContext, spanContext)
    }
}

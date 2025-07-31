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

import OTLPCore
import Tracing
import XCTest

final class SpanStatusProtoTests: XCTestCase {
    func test_init_withStatusOK() {
        let status = Opentelemetry_Proto_Trace_V1_Status(SpanStatus(code: .ok))

        XCTAssertEqual(status, .with {
            $0.code = .ok
            $0.message = ""
        })
    }

    func test_init_withStatusError_withMessage() {
        let status = Opentelemetry_Proto_Trace_V1_Status(SpanStatus(code: .error, message: "test"))

        XCTAssertEqual(status, .with {
            $0.code = .error
            $0.message = "test"
        })
    }
}

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

final class SpanEventProtoTests: XCTestCase {
    func test_init_withSpanEvent() {
        let spanEvent = SpanEvent(name: "test", at: .constant(42), attributes: ["test": 42])
        let event = Opentelemetry_Proto_Trace_V1_Span.Event(spanEvent)

        XCTAssertEqual(event, .with {
            $0.name = "test"
            $0.timeUnixNano = 42
            $0.attributes = [
                .with {
                    $0.key = "test"
                    $0.value = .with { $0.intValue = 42 }
                },
            ]
        })
    }
}

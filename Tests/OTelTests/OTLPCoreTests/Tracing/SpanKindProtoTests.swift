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

final class SpanKindProtoTests: XCTestCase {
    func test_init_withSpanKind_server() {
        XCTAssertEqual(Opentelemetry_Proto_Trace_V1_Span.SpanKind(SpanKind.server), .server)
    }

    func test_init_withSpanKind_client() {
        XCTAssertEqual(Opentelemetry_Proto_Trace_V1_Span.SpanKind(SpanKind.client), .client)
    }

    func test_init_withSpanKind_producer() {
        XCTAssertEqual(Opentelemetry_Proto_Trace_V1_Span.SpanKind(SpanKind.producer), .producer)
    }

    func test_init_withSpanKind_consumer() {
        XCTAssertEqual(Opentelemetry_Proto_Trace_V1_Span.SpanKind(SpanKind.consumer), .consumer)
    }

    func test_init_withSpanKind_internal() {
        XCTAssertEqual(Opentelemetry_Proto_Trace_V1_Span.SpanKind(SpanKind.internal), .internal)
    }
}

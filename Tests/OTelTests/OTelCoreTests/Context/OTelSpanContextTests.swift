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

@testable import OTel
import W3CTraceContext
import XCTest

final class OTelSpanContextTests: XCTestCase {
    func test_local_withoutParentSpanID() {
        let spanContext = OTelSpanContext.local(
            traceID: .oneToSixteen,
            spanID: .oneToEight,
            parentSpanID: nil,
            traceFlags: [],
            traceState: TraceState()
        )

        XCTAssertFalse(spanContext.isRemote)
        XCTAssertEqual(spanContext.traceID, .oneToSixteen)
        XCTAssertEqual(spanContext.spanID, .oneToEight)
        XCTAssertNil(spanContext.parentSpanID)
        XCTAssertTrue(spanContext.traceFlags.isEmpty)
        XCTAssertTrue(spanContext.traceState.isEmpty)
    }

    func test_localWithParentSpanID() {
        let spanContext = OTelSpanContext.local(
            traceID: .oneToSixteen,
            spanID: .oneToEight,
            parentSpanID: .oneToEight,
            traceFlags: [],
            traceState: TraceState()
        )

        XCTAssertFalse(spanContext.isRemote)
        XCTAssertEqual(spanContext.traceID, .oneToSixteen)
        XCTAssertEqual(spanContext.spanID, .oneToEight)
        XCTAssertEqual(spanContext.parentSpanID, .oneToEight)
        XCTAssertTrue(spanContext.traceFlags.isEmpty)
        XCTAssertTrue(spanContext.traceState.isEmpty)
    }

    func test_remote() {
        let spanContext = OTelSpanContext.remote(
            traceContext: TraceContext(
                traceID: .oneToSixteen,
                spanID: .oneToEight,
                flags: [],
                state: TraceState()
            )
        )

        XCTAssertTrue(spanContext.isRemote)
        XCTAssertEqual(spanContext.traceID, .oneToSixteen)
        XCTAssertEqual(spanContext.spanID, .oneToEight)
        XCTAssertNil(spanContext.parentSpanID)
        XCTAssertTrue(spanContext.traceFlags.isEmpty)
        XCTAssertTrue(spanContext.traceState.isEmpty)
    }

    func test_setTraceState() {
        var spanContext = OTelSpanContext.localStub(traceState: TraceState())
        XCTAssertTrue(spanContext.traceState.isEmpty)

        spanContext.traceState[.simple("1")] = "42"

        XCTAssertEqual(spanContext.traceState, TraceState([(.simple("1"), "42")]))
    }

    func test_traceParentHeaderValue() {
        let spanContext = OTelSpanContext.localStub(traceID: .oneToSixteen, spanID: .oneToEight, traceFlags: .sampled)

        XCTAssertEqual(spanContext.traceParentHeaderValue, "00-0102030405060708090a0b0c0d0e0f10-0102030405060708-01")
    }

    func test_traceStateHeaderValue_withEmptyTraceState_returnsNil() {
        let spanContext = OTelSpanContext.localStub(traceState: TraceState())

        XCTAssertNil(spanContext.traceStateHeaderValue)
    }

    func test_traceStateHeaderValue_withTraceStateEntries_returnsValue() {
        let traceState = TraceState([(.simple("1"), "42"), (.simple("2"), "84")])
        let spanContext = OTelSpanContext.localStub(traceState: traceState)

        XCTAssertEqual(spanContext.traceStateHeaderValue, "1=42, 2=84")
    }
}

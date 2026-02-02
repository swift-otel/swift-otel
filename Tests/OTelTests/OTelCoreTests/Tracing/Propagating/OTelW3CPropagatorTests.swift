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

import W3CTraceContext
import XCTest

@testable import OTel

final class OTelW3CPropagatorTests: XCTestCase {
    private let propagator = OTelW3CPropagator()
    private let injector = DictionaryInjector()
    private let extractor = DictionaryExtractor()

    // MARK: - Inject

    func test_injectsTraceparentHeader_notSampled() {
        let spanContext = OTelSpanContext.local(
            traceID: .oneToSixteen,
            spanID: .oneToEight,
            parentSpanID: .oneToEight,
            traceFlags: [],
            traceState: TraceState()
        )
        var headers = [String: String]()

        propagator.inject(spanContext, into: &headers, using: injector)

        XCTAssertEqual(headers, ["traceparent": "00-0102030405060708090a0b0c0d0e0f10-0102030405060708-00"])
    }

    func test_injectsTraceparentHeader_sampled() {
        let spanContext = OTelSpanContext.local(
            traceID: .oneToSixteen,
            spanID: .oneToEight,
            parentSpanID: .oneToEight,
            traceFlags: .sampled,
            traceState: TraceState()
        )
        var headers = [String: String]()

        propagator.inject(spanContext, into: &headers, using: injector)

        XCTAssertEqual(headers, ["traceparent": "00-0102030405060708090a0b0c0d0e0f10-0102030405060708-01"])
    }

    func test_injectsTraceparentAndTracestateHeaders() {
        let spanContext = OTelSpanContext.local(
            traceID: .oneToSixteen,
            spanID: .oneToEight,
            parentSpanID: .oneToEight,
            traceFlags: .sampled,
            traceState: TraceState([
                (.simple("test1"), "123"),
                (.simple("test2"), "abc"),
            ])
        )
        var headers = [String: String]()

        propagator.inject(spanContext, into: &headers, using: injector)

        XCTAssertEqual(headers["traceparent"], "00-0102030405060708090a0b0c0d0e0f10-0102030405060708-01")
        XCTAssertEqual(headers["tracestate"], "test1=123, test2=abc")
    }

    // MARK: - Extract

    func test_extractsNil_withoutW3CHeaders() throws {
        let headers = ["Content-Type": "application/json"]

        XCTAssertNil(try propagator.extractSpanContext(from: headers, using: extractor))
    }

    func test_extractsNil_withoutTraceparentHeader() throws {
        let headers = ["tracestate": "test1=123,test2=abc"]

        XCTAssertNil(try propagator.extractSpanContext(from: headers, using: extractor))
    }

    func test_extractsTraceparentHeader_notSampled() throws {
        let headers = ["traceparent": "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00"]

        let spanContext = try XCTUnwrap(propagator.extractSpanContext(from: headers, using: extractor))

        XCTAssertEqual(String(describing: spanContext.traceID), "0af7651916cd43dd8448eb211c80319c")
        XCTAssertEqual(String(describing: spanContext.spanID), "b7ad6b7169203331")
        XCTAssertTrue(spanContext.traceFlags.isEmpty)
        XCTAssertTrue(spanContext.traceState.isEmpty)
    }

    func test_extractsTraceparentHeader_sampled() throws {
        let headers = ["traceparent": "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"]

        let spanContext = try XCTUnwrap(propagator.extractSpanContext(from: headers, using: extractor))

        XCTAssertEqual(String(describing: spanContext.traceID), "0af7651916cd43dd8448eb211c80319c")
        XCTAssertEqual(String(describing: spanContext.spanID), "b7ad6b7169203331")
        XCTAssertEqual(spanContext.traceFlags, .sampled)
        XCTAssertTrue(spanContext.traceState.isEmpty)
    }

    func test_extractsTraceparentAndTracestateHeader() throws {
        let headers = [
            "traceparent": "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01",
            "tracestate": "test1=123,test2=abc",
        ]

        let spanContext = try XCTUnwrap(propagator.extractSpanContext(from: headers, using: extractor))

        XCTAssertEqual(String(describing: spanContext.traceID), "0af7651916cd43dd8448eb211c80319c")
        XCTAssertEqual(String(describing: spanContext.spanID), "b7ad6b7169203331")
        XCTAssertEqual(spanContext.traceFlags, .sampled)
        XCTAssertEqual(
            spanContext.traceState,
            TraceState([
                (.simple("test1"), "123"),
                (.simple("test2"), "abc"),
            ])
        )
    }

    func test_extractSupportsTracestateMultiTenantNotation() throws {
        let headers = [
            "traceparent": "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01",
            "tracestate": "customer1@test=123,customer2@test=abc",
        ]

        let spanContext = try XCTUnwrap(propagator.extractSpanContext(from: headers, using: extractor))

        XCTAssertEqual(
            spanContext.traceState,
            TraceState([
                (.tenant("customer1", in: "test"), "123"),
                (.tenant("customer2", in: "test"), "abc"),
            ])
        )
    }

    // MARK: - End To End

    func test_injectExtractedSpanContext() throws {
        let headers = [
            "traceparent": "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01",
            "tracestate": "key=value",
        ]

        let extractedSpanContext = try XCTUnwrap(propagator.extractSpanContext(from: headers, using: extractor))

        var injectedHeaders = [String: String]()

        propagator.inject(extractedSpanContext, into: &injectedHeaders, using: injector)

        XCTAssertEqual(injectedHeaders["traceparent"], headers["traceparent"])
        XCTAssertEqual(headers["tracestate"], headers["tracestate"])
    }
}

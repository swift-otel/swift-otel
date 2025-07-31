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
import W3CTraceContext
import XCTest

final class OTelMultiplexPropagatorTests: XCTestCase {
    private let injector = DictionaryInjector()
    private let extractor = DictionaryExtractor()

    // MARK: - Inject

    func test_invokesInjectOnAllPropagators() {
        let spanContext = OTelSpanContext.localStub(
            traceID: .oneToSixteen,
            spanID: .oneToEight,
            parentSpanID: nil,
            traceFlags: [],
            traceState: TraceState()
        )
        var headers = [String: String]()

        let propagator = OTelMultiplexPropagator([SystemAPropagator(), SystemBPropagator()])
        propagator.inject(spanContext, into: &headers, using: injector)

        XCTAssertEqual(headers["a-trace-id"], "0102030405060708090a0b0c0d0e0f10-0102030405060708")
        XCTAssertEqual(headers["b-trace-id"], "100f0e0d0c0b0a090807060504030201-0807060504030201")
    }

    // MARK: - Extract

    func test_extractsNil_allPropagatorsReturningNil() throws {
        let headers = ["c-trace-id": "valid"]

        let propagator = OTelMultiplexPropagator([SystemAPropagator(), SystemBPropagator()])
        XCTAssertNil(try propagator.extractSpanContext(from: headers, using: extractor))
    }

    func test_extractsSystemAHeader() throws {
        let headers = ["a-trace-id": "valid"]

        let propagator = OTelMultiplexPropagator([SystemAPropagator(), SystemBPropagator()])
        let spanContext = try XCTUnwrap(propagator.extractSpanContext(from: headers, using: extractor))

        XCTAssertEqual(spanContext.traceID, SystemAPropagator.validTraceID)
        XCTAssertEqual(spanContext.spanID, SystemAPropagator.validSpanID)
    }

    func test_extractsSystemAHeader_reverseOrder() throws {
        let headers = ["a-trace-id": "valid"]

        let propagator = OTelMultiplexPropagator([SystemBPropagator(), SystemAPropagator()])
        let spanContext = try XCTUnwrap(propagator.extractSpanContext(from: headers, using: extractor))

        XCTAssertEqual(spanContext.traceID, SystemAPropagator.validTraceID)
        XCTAssertEqual(spanContext.spanID, SystemAPropagator.validSpanID)
    }

    func test_extractsSystemBHeader() throws {
        let headers = ["b-trace-id": "valid"]

        let propagator = OTelMultiplexPropagator([SystemAPropagator(), SystemBPropagator()])
        let spanContext = try XCTUnwrap(propagator.extractSpanContext(from: headers, using: extractor))

        XCTAssertEqual(spanContext.traceID, SystemBPropagator.validTraceID)
        XCTAssertEqual(spanContext.spanID, SystemBPropagator.validSpanID)
    }

    func test_extractsSystemBHeader_reverseOrder() throws {
        let headers = ["b-trace-id": "valid"]

        let propagator = OTelMultiplexPropagator([SystemBPropagator(), SystemAPropagator()])
        let spanContext = try XCTUnwrap(propagator.extractSpanContext(from: headers, using: extractor))

        XCTAssertEqual(spanContext.traceID, SystemBPropagator.validTraceID)
        XCTAssertEqual(spanContext.spanID, SystemBPropagator.validSpanID)
    }

    func test_extractsBothSystemHeaders() throws {
        let headers = ["a-trace-id": "valid", "b-trace-id": "valid"]

        let propagator = OTelMultiplexPropagator([SystemAPropagator(), SystemBPropagator()])
        let spanContext = try XCTUnwrap(propagator.extractSpanContext(from: headers, using: extractor))

        XCTAssertEqual(spanContext.traceID, SystemBPropagator.validTraceID)
        XCTAssertEqual(spanContext.spanID, SystemBPropagator.validSpanID)
    }

    func test_extractsBothSystemHeaders_reverseOrder() throws {
        let headers = ["a-trace-id": "valid", "b-trace-id": "valid"]

        let propagator = OTelMultiplexPropagator([SystemBPropagator(), SystemAPropagator()])
        let spanContext = try XCTUnwrap(propagator.extractSpanContext(from: headers, using: extractor))

        XCTAssertEqual(spanContext.traceID, SystemAPropagator.validTraceID)
        XCTAssertEqual(spanContext.spanID, SystemAPropagator.validSpanID)
    }
}

private struct SystemAPropagator: OTelPropagator {
    static let validTraceID = TraceID.oneToSixteen
    static let validSpanID = SpanID.oneToEight

    public func extractSpanContext<Carrier, Extract>(
        from carrier: Carrier,
        using extractor: Extract
    ) throws -> OTelSpanContext? where Extract: Extractor, Carrier == Extract.Carrier {
        guard let value = extractor.extract(key: "a-trace-id", from: carrier) else { return nil }
        guard value == "valid" else { throw PropagatorError() }
        return OTelSpanContext.remoteStub(
            traceID: Self.validTraceID,
            spanID: Self.validSpanID,
            traceFlags: [],
            traceState: TraceState()
        )
    }

    public func inject<Carrier, Inject>(
        _ spanContext: OTelSpanContext,
        into carrier: inout Carrier,
        using injector: Inject
    ) where Inject: Injector, Carrier == Inject.Carrier {
        injector.inject("\(Self.validTraceID)-\(Self.validSpanID)", forKey: "a-trace-id", into: &carrier)
    }
}

private struct SystemBPropagator: OTelPropagator {
    static let validTraceID = TraceID(bytes: .init((16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1)))
    static let validSpanID = SpanID(bytes: .init((8, 7, 6, 5, 4, 3, 2, 1)))

    public func extractSpanContext<Carrier, Extract>(
        from carrier: Carrier,
        using extractor: Extract
    ) throws -> OTelSpanContext? where Extract: Extractor, Carrier == Extract.Carrier {
        guard let value = extractor.extract(key: "b-trace-id", from: carrier) else { return nil }
        guard value == "valid" else { throw PropagatorError() }
        return OTelSpanContext.remoteStub(
            traceID: Self.validTraceID,
            spanID: Self.validSpanID,
            traceFlags: [],
            traceState: TraceState()
        )
    }

    public func inject<Carrier, Inject>(
        _ spanContext: OTelSpanContext,
        into carrier: inout Carrier,
        using injector: Inject
    ) where Inject: Injector, Carrier == Inject.Carrier {
        injector.inject("\(Self.validTraceID)-\(Self.validSpanID)", forKey: "b-trace-id", into: &carrier)
    }
}

private struct PropagatorError: Error {}

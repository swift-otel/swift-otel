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

import Tracing
import W3CTraceContext
import XCTest

@testable import OTel

final class OTelFinishedSpanProtoTests: XCTestCase {
    func test_initProtoSpan_withFinishedSpan_castsTraceID() {
        let span = OTelFinishedSpan.stub(traceID: .oneToSixteen)

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertEqual(protoSpan.traceID, Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]))
    }

    func test_initProtoSpan_withFinishedSpan_castsSpanID() {
        let span = OTelFinishedSpan.stub(spanID: .oneToEight)

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertEqual(protoSpan.spanID, Data([1, 2, 3, 4, 5, 6, 7, 8]))
    }

    func test_initProtoSpan_withFinishedSpan_withTraceState_castsTraceState() {
        let traceState = TraceState([
            (.simple("test1"), "42"),
            (.simple("test2"), "84"),
        ])
        let span = OTelFinishedSpan.stub(traceState: traceState)

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertEqual(protoSpan.traceState, "test1=42, test2=84")
    }

    func test_initProtoSpan_withFinishedSpan_withoutTraceState_doesNotSetTraceState() {
        let span = OTelFinishedSpan.stub(traceState: TraceState())

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertTrue(protoSpan.traceState.isEmpty)
    }

    func test_initProtoSpan_withFinishedSpan_withParentSpanID_setsParentSpanID() {
        let parentSpanID = SpanID.oneToEight
        let span = OTelFinishedSpan.stub(parentSpanID: parentSpanID)

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertEqual(protoSpan.parentSpanID, Data([1, 2, 3, 4, 5, 6, 7, 8]))
    }

    func test_initProtoSpan_withFinishedSpan_withoutParentSpanID_doesNotSetParentSpanID() {
        let span = OTelFinishedSpan.stub(parentSpanID: nil)

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertTrue(protoSpan.parentSpanID.isEmpty)
    }

    func test_initProtoSpan_withFinishedSpan_setsOperationName() {
        let span = OTelFinishedSpan.stub(operationName: "test")

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertEqual(protoSpan.name, "test")
    }

    func test_initProtoSpan_withFinishedSpan_castsSpanKind() {
        let span = OTelFinishedSpan.stub(kind: .server)

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertEqual(protoSpan.kind, .server)
    }

    func test_initProtoSpan_withFinishedSpan_setsStartTimeUnixNano() {
        let span = OTelFinishedSpan.stub(startTimeNanosecondsSinceEpoch: 42)

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertEqual(protoSpan.startTimeUnixNano, 42)
    }

    func test_initProtoSpan_withFinishedSpan_setsEndTimeUnixNano() {
        let span = OTelFinishedSpan.stub(endTimeNanosecondsSinceEpoch: 42)

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertEqual(protoSpan.endTimeUnixNano, 42)
    }

    func test_initProtoSpan_withFinishedSpan_withStatus_castsSpanStatus() {
        let status = SpanStatus(code: .error, message: "test")
        let span = OTelFinishedSpan.stub(status: status)

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertEqual(
            protoSpan.status,
            .with {
                $0.code = .error
                $0.message = "test"
            }
        )
    }

    func test_initProtoSpan_withFinishedSpan_withoutStatus_doesNotSetSpanStatus() {
        let span = OTelFinishedSpan.stub(status: nil)

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertEqual(
            protoSpan.status,
            .with {
                $0.code = .unset
                $0.message = ""
            }
        )
    }

    func test_initProtoSpan_withFinishedSpan_withAttributes_castsAttributes() throws {
        let attributes: SpanAttributes = ["test": 42]
        let span = OTelFinishedSpan.stub(attributes: attributes)

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertEqual(
            protoSpan.attributes,
            [
                .with {
                    $0.key = "test"
                    $0.value = .with { $0.intValue = 42 }
                }
            ]
        )
    }

    func test_initProtoSpan_withFinishedSpan_withoutAttributes_doesNotSetAttributes() {
        let span = OTelFinishedSpan.stub(attributes: [:])

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertTrue(protoSpan.attributes.isEmpty)
    }

    func test_initProtoSpan_withFinishedSpan_withEvents_castsEvents() throws {
        let span = OTelFinishedSpan.stub(events: [
            SpanEvent(name: "test", at: .constant(42), attributes: ["test": 42])
        ])

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertEqual(
            protoSpan.events,
            [
                .with {
                    $0.name = "test"
                    $0.timeUnixNano = 42
                    $0.attributes = [
                        .with {
                            $0.key = "test"
                            $0.value = .with { $0.intValue = 42 }
                        }
                    ]
                }
            ]
        )
    }

    func test_initProtoSpan_withFinishedSpan_withoutEvents_doesNotSetEvents() {
        let span = OTelFinishedSpan.stub(events: [])

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertTrue(protoSpan.events.isEmpty)
    }

    func test_initProtoSpan_withFinishedSpan_withLinks_castsLinks() throws {
        var context = ServiceContext.topLevel
        context.spanContext = .localStub(
            traceID: .oneToSixteen,
            spanID: .oneToEight,
            traceState: TraceState([(.simple("test"), "42")])
        )
        let span = OTelFinishedSpan.stub(links: [
            SpanLink(context: context, attributes: ["test": 42])
        ])

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertEqual(
            protoSpan.links,
            [
                .with {
                    $0.traceID = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16])
                    $0.spanID = Data([1, 2, 3, 4, 5, 6, 7, 8])
                    $0.traceState = "test=42"
                    $0.attributes = [
                        .with {
                            $0.key = "test"
                            $0.value = .with { $0.intValue = 42 }
                        }
                    ]
                }
            ]
        )
    }

    func test_initProtoSpan_withFinishedSpan_withoutLinks_doesNotSetLinks() {
        let span = OTelFinishedSpan.stub(links: [])

        let protoSpan = Opentelemetry_Proto_Trace_V1_Span(span)

        XCTAssertTrue(protoSpan.links.isEmpty)
    }
}

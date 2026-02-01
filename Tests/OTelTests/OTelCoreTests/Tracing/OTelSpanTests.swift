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
import XCTest

@testable import OTel

final class OTelSpanTests: XCTestCase {
    // MARK: - context

    func test_context_whenNoOp_returnsContext() {
        let context = ServiceContext.withStubValue(42)

        let span = OTelSpan.noOpStub(context: context)

        XCTAssertEqual(span.context.stubValue, 42)
    }

    func test_context_whenSampled_returnsContext() {
        let context = ServiceContext.withStubValue(42)

        let span = OTelSpan.recordingStub(context: context)

        XCTAssertEqual(span.context.stubValue, 42)
    }

    // MARK: - isRecording

    func test_isRecording_whenNoOp_whenNotEnded_returnsFalse() {
        let span = OTelSpan.noOpStub()

        XCTAssertFalse(span.isRecording)
    }

    func test_isRecording_whenNoOp_whenEnded_returnsFalse() {
        let span = OTelSpan.noOpStub()
        span.end()

        XCTAssertFalse(span.isRecording)
    }

    func test_isRecording_whenSampled_whenNotEnded_returnsTrue() {
        let span = OTelSpan.recordingStub()

        XCTAssertTrue(span.isRecording)
    }

    func test_isRecording_whenSampled_whenEnded_returnsFalse() {
        let span = OTelSpan.recordingStub()
        span.end()

        XCTAssertFalse(span.isRecording)
    }

    // MARK: - operationName

    func test_operationName_get_whenNoOp_returnsPlaceholder() {
        let span = OTelSpan.noOpStub()

        XCTAssertEqual(span.operationName, NoOpTracer.NoOpSpan(context: .topLevel).operationName)
    }

    func test_operationName_get_whenSampled_returnsPlaceholder() {
        let span = OTelSpan.recordingStub(operationName: "test")

        XCTAssertEqual(span.operationName, "test")
    }

    func test_operationName_set_whenNoOp_doesNotUpdateOperationName() {
        let span = OTelSpan.noOpStub()

        span.operationName = "updated"

        XCTAssertNotEqual(span.operationName, "updated")
    }

    func test_operationName_set_whenSampled_whenNotEnded_updatesOperationName() {
        let span = OTelSpan.recordingStub(operationName: "original")

        span.operationName = "updated"

        XCTAssertEqual(span.operationName, "updated")
    }

    func test_operationName_set_whenSampled_whenEnded_doesNotUpdateOperationName() {
        let span = OTelSpan.recordingStub(operationName: "original")

        span.end()
        span.operationName = "updated"

        XCTAssertEqual(span.operationName, "original")
    }

    // MARK: - attributes

    func test_attributes_get_whenNoOp_returnsEmptyArray() {
        let span = OTelSpan.noOpStub()

        XCTAssertTrue(span.attributes.isEmpty)
    }

    func test_attributes_get_whenSampled_defaultsToInitialAttributes() {
        let span = OTelSpan.recordingStub(attributes: ["initial": 42])

        XCTAssertEqual(span.attributes, ["initial": 42])
    }

    func test_attributes_set_whenNoOp_doesNotUpdateAttributes() {
        let span = OTelSpan.noOpStub()

        span.attributes["test"] = 42

        XCTAssertTrue(span.attributes.isEmpty)
    }

    func test_attributes_set_whenSampled_whenNotEnded_updatesAttributes() {
        let span = OTelSpan.recordingStub(attributes: ["initial": 42])

        span.attributes["test"] = 42

        XCTAssertEqual(span.attributes, ["initial": 42, "test": 42])
    }

    func test_attributes_set_whenSampled_whenEnded_doesNotUpdateAttributes() {
        let span = OTelSpan.recordingStub(attributes: ["initial": 42])
        span.end()

        span.attributes["test"] = 42

        XCTAssertEqual(span.attributes, ["initial": 42])
    }

    // MARK: - events

    func test_events_get_whenNoOp_returnsEmptyArray() {
        let span = OTelSpan.noOpStub()

        XCTAssertTrue(span.events.isEmpty)
    }

    func test_events_get_whenSampled_defaultsToEmptyArray() {
        let span = OTelSpan.recordingStub()

        XCTAssertTrue(span.events.isEmpty)
    }

    func test_addEvent_whenNoOp_doesNotAddEvent() {
        let span = OTelSpan.noOpStub()

        span.addEvent("test")

        XCTAssertTrue(span.events.isEmpty)
    }

    func test_addEvent_whenSampled_whenNotEnded_addsEvent() {
        let span = OTelSpan.recordingStub()

        let event = SpanEvent(
            name: "test",
            at: .constant(42),
            attributes: ["test": 42]
        )
        span.addEvent(event)

        XCTAssertEqual(span.events, [event])
    }

    func test_addEvent_whenSampled_whenEnded_doesNotAddEvent() {
        let span = OTelSpan.recordingStub()
        span.end()

        span.addEvent("test")

        XCTAssertTrue(span.events.isEmpty)
    }

    // MARK: - recordError

    func test_recordError_whenNoOp_doesNotAddEvent() {
        let span = OTelSpan.noOpStub()

        span.recordError(TestError.test(value: 42))

        XCTAssertTrue(span.events.isEmpty)
    }

    func test_recordError_whenSampled_whenNotEnded_addsEvent() {
        let span = OTelSpan.recordingStub()

        span.recordError(
            TestError.test(value: 42),
            attributes: ["adhoc": 42],
            at: .constant(42)
        )

        XCTAssertEqual(
            span.events,
            [
                SpanEvent(
                    name: "exception",
                    at: .constant(42),
                    attributes: [
                        "adhoc": 42,
                        "exception.type": "TestError",
                        "exception.message": "test(value: 42)",
                    ]
                )
            ]
        )
    }

    func test_recordError_whenSampled_whenEnded_doesNotAddEvent() {
        let span = OTelSpan.recordingStub()
        span.end()

        span.recordError(TestError.test(value: 42))

        XCTAssertTrue(span.events.isEmpty)
    }

    // MARK: - links

    func test_links_get_whenNoOp_defaultsToEmptyArray() {
        let span = OTelSpan.noOpStub()

        XCTAssertTrue(span.links.isEmpty)
    }

    func test_links_get_whenSampled_defaultsToEmptyArray() {
        let span = OTelSpan.recordingStub()

        XCTAssertTrue(span.links.isEmpty)
    }

    func test_addLink_whenNoOp_doesNotAddLink() {
        let span = OTelSpan.noOpStub()

        span.addLink(SpanLink(context: .topLevel, attributes: [:]))

        XCTAssertTrue(span.links.isEmpty)
    }

    func test_addLink_whenSampled_whenNotEnded_addsLink() throws {
        let span = OTelSpan.recordingStub()

        let linkedContext = ServiceContext.withStubValue(42)
        span.addLink(SpanLink(context: linkedContext, attributes: ["test": 42]))

        XCTAssertEqual(span.links.count, 1)
        let link = try XCTUnwrap(span.links.first)

        XCTAssertEqual(link.context.stubValue, 42)
        XCTAssertEqual(link.attributes, ["test": 42])
    }

    func test_addLink_whenSampled_whenEnded_doesNotAddLink() {
        let span = OTelSpan.recordingStub()
        span.end()

        span.addLink(SpanLink(context: .topLevel, attributes: [:]))

        XCTAssertTrue(span.links.isEmpty)
    }

    // MARK: - status

    func test_status_get_whenNoOp_defaultsToNil() {
        let span = OTelSpan.noOpStub()

        XCTAssertNil(span.status)
    }

    func test_status_get_whenSampled_defaultsToNil() {
        let span = OTelSpan.noOpStub()

        XCTAssertNil(span.status)
    }

    func test_setStatus_whenNoOp_doesNotSetStatus() {
        let span = OTelSpan.noOpStub()

        span.setStatus(.init(code: .ok))

        XCTAssertNil(span.status)
    }

    func test_setStatus_whenSampled_whenNotEnded_setsStatus() {
        let span = OTelSpan.recordingStub()

        let status = SpanStatus(code: .error, message: "test")
        span.setStatus(status)

        XCTAssertEqual(span.status, status)
    }

    func test_setStatus_whenSampled_whenNotEnded_whenStatusOK_setsStatusWithoutMessage() {
        let span = OTelSpan.recordingStub()

        let status = SpanStatus(code: .ok, message: "test")
        span.setStatus(status)

        XCTAssertEqual(span.status, SpanStatus(code: .ok))
    }

    func test_setStatus_whenSampled_whenNotEnded_whenAlreadySetToOK_doesNotUpdateStatus() {
        let span = OTelSpan.recordingStub()
        span.setStatus(.init(code: .ok))

        let status = SpanStatus(code: .error, message: "test")
        span.setStatus(status)

        XCTAssertEqual(span.status, SpanStatus(code: .ok))
    }

    func test_setStatus_whenSampled_whenNotEnded_whenSetToError_updatesStatus() {
        let span = OTelSpan.recordingStub()
        span.setStatus(.init(code: .error, message: "test"))

        span.setStatus(SpanStatus(code: .ok))

        XCTAssertEqual(span.status, SpanStatus(code: .ok))
    }

    func test_setStatus_whenSampled_whenEnded_doesNotSetStatus() {
        let span = OTelSpan.recordingStub()
        span.end()

        span.setStatus(.init(code: .ok))

        XCTAssertNil(span.status)
    }

    // MARK: - end

    func test_endTimeNanosecondsSinceEpoch_whenNoOp_defaultsToNil() {
        let span = OTelSpan.noOpStub()

        XCTAssertNil(span.endTimeNanosecondsSinceEpoch)
    }

    func test_endTimeNanosecondsSinceEpoch_whenSampled_defaultsToNil() {
        let span = OTelSpan.noOpStub()

        XCTAssertNil(span.endTimeNanosecondsSinceEpoch)
    }

    func test_end_whenNoOp_doesNotSetEndTimeNanosecondsSinceEpoch() {
        let span = OTelSpan.recordingStub()

        span.end(at: .constant(42))

        XCTAssertEqual(span.endTimeNanosecondsSinceEpoch, 42)
    }

    func test_end_whenSampled_whenNotEnded_setsEndTimeNanosecondsSinceEpoch() {
        let span = OTelSpan.recordingStub()

        span.end(at: .constant(42))

        XCTAssertEqual(span.endTimeNanosecondsSinceEpoch, 42)
    }

    func test_end_whenSampled_whenAlreadyEnded_doesNotSetEndTimeNanosecondsSinceEpoch() {
        let span = OTelSpan.recordingStub()
        span.end(at: .constant(42))

        span.end(at: .constant(84))

        XCTAssertEqual(span.endTimeNanosecondsSinceEpoch, 42)
    }
}

// MARK: - Helpers

private enum TestError: Error {
    case test(value: Int)
}

extension NoOpTracer.NoOpSpan {
    fileprivate static let topLevel = NoOpTracer.NoOpSpan(context: .topLevel)
}

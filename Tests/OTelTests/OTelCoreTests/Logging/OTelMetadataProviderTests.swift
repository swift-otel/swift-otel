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
import XCTest

@testable import Logging
@testable import OTel

final class MetadataProviderTests: XCTestCase {
    func test_providesMetadataFromSpanContext_withDefaultLabels() throws {
        guard #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) else {
            throw XCTSkip("Task locals are not supported on this platform.")
        }

        let stream = InterceptingStream()
        var logger = Logger(label: "test")
        logger.handler = StreamLogHandler(label: "test", stream: stream, metadataProvider: .otel)

        let spanContext = OTelSpanContext.localStub(traceID: .oneToSixteen, spanID: .oneToEight, traceFlags: .sampled)

        var context = ServiceContext.topLevel
        context.spanContext = spanContext
        ServiceContext.$current.withValue(context) {
            logger.info("This is a test message", metadata: ["explicit": "42"])
        }

        XCTAssertEqual(stream.strings.count, 1)
        let message = try XCTUnwrap(stream.strings.first)

        XCTAssertTrue(message.contains("span_id=\(spanContext.spanID)"))
        XCTAssertTrue(message.contains("trace_id=\(spanContext.traceID)"))
        XCTAssertTrue(message.contains("trace_flags=1"))
        XCTAssertTrue(message.contains("explicit=42"))
        XCTAssertTrue(message.contains("This is a test message"))
    }

    func test_providesMetadataFromSpanContext_withCustomLabels() throws {
        guard #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) else {
            throw XCTSkip("Task locals are not supported on this platform.")
        }

        let stream = InterceptingStream()
        var logger = Logger(label: "test")
        let metadataProvider = Logger.MetadataProvider.otel(
            traceIDKey: "custom_trace_id",
            spanIDKey: "custom_span_id",
            traceFlagsKey: "custom_trace_flags",
            parentSpanIDKey: "custom_parent_span_id"
        )
        logger.handler = StreamLogHandler(label: "test", stream: stream, metadataProvider: metadataProvider)

        let spanContext = OTelSpanContext.localStub(
            traceID: .oneToSixteen,
            spanID: .oneToEight,
            parentSpanID: .oneToEight,
            traceFlags: []
        )

        var context = ServiceContext.topLevel
        context.spanContext = spanContext
        ServiceContext.$current.withValue(context) {
            logger.info("This is a test message", metadata: ["explicit": "42"])
        }

        XCTAssertEqual(stream.strings.count, 1)
        let message = try XCTUnwrap(stream.strings.first)

        XCTAssertTrue(message.contains("custom_span_id=\(spanContext.spanID)"))
        XCTAssertTrue(message.contains("custom_trace_id=\(spanContext.traceID)"))
        XCTAssertTrue(message.contains("custom_trace_flags=0"))
        XCTAssertTrue(try message.contains("custom_parent_span_id=\(XCTUnwrap(spanContext.parentSpanID))"))
        XCTAssertTrue(message.contains("explicit=42"))
        XCTAssertTrue(message.contains("This is a test message"))
    }

    func test_doesNotProvideMetadataWithoutSpanContext() throws {
        guard #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) else {
            throw XCTSkip("Task locals are not supported on this platform.")
        }

        let stream = InterceptingStream()
        var logger = Logger(label: "test")
        let metadataProvider = Logger.MetadataProvider.otel
        logger.handler = StreamLogHandler(label: "test", stream: stream, metadataProvider: metadataProvider)

        logger.info("This is a test message", metadata: ["explicit": "42"])

        XCTAssertEqual(stream.strings.count, 1)
        let message = try XCTUnwrap(stream.strings.first)

        XCTAssertFalse(message.contains("trace-id"))
        XCTAssertFalse(message.contains("span-id"))
        XCTAssertTrue(message.contains("explicit=42"))
        XCTAssertTrue(message.contains("This is a test message"))
    }
}

final class InterceptingStream: TextOutputStream {
    var interceptedText: String?
    var strings = [String]()

    func write(_ string: String) {
        strings.append(string)
        interceptedText = (interceptedText ?? "") + string
    }
}

extension InterceptingStream: @unchecked Sendable {}

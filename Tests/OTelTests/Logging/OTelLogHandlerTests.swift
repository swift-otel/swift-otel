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

@testable import Logging
@_spi(Logging) import OTel
import OTelTesting
import XCTest

final class OTelLogHandlerTests: XCTestCase {
    private let resource = OTelResource(attributes: ["service.name": "log_handler_tests"])

    func test_log_withoutMetadata_forwardsLogRecordToProcessor() {
        let processor = OTelInMemoryLogRecordProcessor()
        let logger = Logger(label: #function) { _ in
            OTelLogHandler(
                processor: processor,
                logLevel: .info,
                resource: resource,
                metadata: [:],
                nanosecondsSinceEpoch: { 42 }
            )
        }

        logger.info(.stub, file: "file", function: "function", line: 42)

        XCTAssertEqual(processor.records, [
            .stub(
                metadata: ["code.filepath": "file", "code.function": "function", "code.lineno": "42"],
                resource: resource
            ),
        ])
    }

    func test_log_withLoggerMetadata_includesMetadataInLogRecord() {
        let processor = OTelInMemoryLogRecordProcessor()
        var logger = Logger(label: #function) { _ in
            OTelLogHandler(
                processor: processor,
                logLevel: .info,
                resource: resource,
                metadata: [:],
                nanosecondsSinceEpoch: { 42 }
            )
        }
        logger[metadataKey: "logger"] = "42"

        logger.info(.stub, file: "file", function: "function", line: 42)

        XCTAssertEqual(processor.records, [
            .stub(
                metadata: ["code.filepath": "file", "code.function": "function", "code.lineno": "42", "logger": "42"],
                resource: resource
            ),
        ])
    }

    func test_log_withLoggerMetadata_overridesCodeMetadata() {
        let processor = OTelInMemoryLogRecordProcessor()
        var logger = Logger(label: #function) { _ in
            OTelLogHandler(
                processor: processor,
                logLevel: .info,
                resource: resource,
                metadata: [:],
                nanosecondsSinceEpoch: { 42 }
            )
        }
        logger[metadataKey: "code.filepath"] = "custom/file/path"

        logger.info(.stub, file: "file", function: "function", line: 42)

        XCTAssertEqual(processor.records, [
            .stub(
                metadata: ["code.filepath": "custom/file/path", "code.function": "function", "code.lineno": "42"],
                resource: resource
            ),
        ])
    }

    func test_log_withHandlerMetadata_includesMetadataInLogRecord() {
        let processor = OTelInMemoryLogRecordProcessor()
        let logger = Logger(label: #function) { _ in
            OTelLogHandler(
                processor: processor,
                logLevel: .info,
                resource: resource,
                metadata: ["handler": "42"],
                nanosecondsSinceEpoch: { 42 }
            )
        }

        logger.info(.stub, file: "file", function: "function", line: 42)

        XCTAssertEqual(processor.records, [
            .stub(
                metadata: ["code.filepath": "file", "code.function": "function", "code.lineno": "42", "handler": "42"],
                resource: resource
            ),
        ])
    }

    func test_log_withHandlerAndLoggerMetadata_overridesHandlerWithLoggerMetadata() {
        let processor = OTelInMemoryLogRecordProcessor()
        var logger = Logger(label: #function) { _ in
            OTelLogHandler(
                processor: processor,
                logLevel: .info,
                resource: resource,
                metadata: ["shared": "handler"],
                nanosecondsSinceEpoch: { 42 }
            )
        }
        logger[metadataKey: "shared"] = "logger"

        logger.info(.stub, file: "file", function: "function", line: 42)

        XCTAssertEqual(processor.records, [
            .stub(
                metadata: [
                    "code.filepath": "file",
                    "code.function": "function",
                    "code.lineno": "42",
                    "shared": "logger",
                ],
                resource: resource
            ),
        ])
    }

    func test_log_withLoggerAndAdHocMetadata_overridesLoggerWithAdHocMetadata() {
        let processor = OTelInMemoryLogRecordProcessor()
        var logger = Logger(label: #function) { _ in
            OTelLogHandler(
                processor: processor,
                logLevel: .info,
                resource: resource,
                metadata: [:],
                nanosecondsSinceEpoch: { 42 }
            )
        }
        logger[metadataKey: "shared"] = "logger"

        logger.info(.stub, metadata: ["shared": "ad-hoc"], file: "file", function: "function", line: 42)

        XCTAssertEqual(processor.records, [
            .stub(
                metadata: [
                    "code.filepath": "file",
                    "code.function": "function",
                    "code.lineno": "42",
                    "shared": "ad-hoc",
                ],
                resource: resource
            ),
        ])
    }

    func test_log_withAdHocMetadata_overridesCodeMetadata() {
        let processor = OTelInMemoryLogRecordProcessor()
        var logger = Logger(label: #function) { _ in
            OTelLogHandler(
                processor: processor,
                logLevel: .info,
                resource: resource,
                metadata: [:],
                nanosecondsSinceEpoch: { 42 }
            )
        }
        logger[metadataKey: "code.lineno"] = "84"

        logger.info(
            .stub,
            metadata: ["code.filepath": "custom/file/path"],
            file: "file",
            function: "function",
            line: 42
        )

        XCTAssertEqual(processor.records, [
            .stub(
                metadata: ["code.filepath": "custom/file/path", "code.function": "function", "code.lineno": "84"],
                resource: resource
            ),
        ])
    }

    func test_loggerMetadataProxiesToHandlerMetadata() throws {
        let processor = OTelInMemoryLogRecordProcessor()
        var logger = Logger(label: #function) { _ in
            OTelLogHandler(
                processor: processor,
                logLevel: .info,
                resource: resource,
                metadata: ["shared": "handler"]
            )
        }

        logger[metadataKey: "shared"] = "logger"
        let handler = try XCTUnwrap(logger.handler)

        XCTAssertEqual(handler[metadataKey: "shared"], "logger")

        logger.info(.stub, file: "file", function: "function", line: 42)

        let record = try XCTUnwrap(processor.records.first)
        XCTAssertEqual(record.metadata, [
            "code.filepath": "file",
            "code.function": "function",
            "code.lineno": "42",
            "shared": "logger",
        ])
    }
}

extension Logger.Message {
    fileprivate static let stub: Logger.Message = "🏎️"
}

extension OTelLogRecord {
    fileprivate static func stub(
        metadata: Logger.Metadata = [:],
        resource: OTelResource = OTelResource()
    ) -> OTelLogRecord {
        OTelLogRecord(
            body: .stub,
            level: .info,
            metadata: metadata,
            timeNanosecondsSinceEpoch: 42,
            resource: resource,
            spanContext: nil
        )
    }
}

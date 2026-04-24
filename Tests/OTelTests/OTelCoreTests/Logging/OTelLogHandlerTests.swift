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
@testable import OTel
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
                metadata: ["code.file.path": "file", "code.function.name": "function", "code.line.number": "42"],
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
                metadata: ["code.file.path": "file", "code.function.name": "function", "code.line.number": "42", "logger": "42"],
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
        logger[metadataKey: "code.file.path"] = "custom/file/path"

        logger.info(.stub, file: "file", function: "function", line: 42)

        XCTAssertEqual(processor.records, [
            .stub(
                metadata: ["code.file.path": "custom/file/path", "code.function.name": "function", "code.line.number": "42"],
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
                metadata: ["code.file.path": "file", "code.function.name": "function", "code.line.number": "42", "handler": "42"],
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
                    "code.file.path": "file",
                    "code.function.name": "function",
                    "code.line.number": "42",
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
                    "code.file.path": "file",
                    "code.function.name": "function",
                    "code.line.number": "42",
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
        logger[metadataKey: "code.line.number"] = "84"

        logger.info(
            .stub,
            metadata: ["code.file.path": "custom/file/path"],
            file: "file",
            function: "function",
            line: 42
        )

        XCTAssertEqual(processor.records, [
            .stub(
                metadata: ["code.file.path": "custom/file/path", "code.function.name": "function", "code.line.number": "84"],
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
            "code.file.path": "file",
            "code.function.name": "function",
            "code.line.number": "42",
            "shared": "logger",
        ])
    }

    func test_log_withErrorParameter_includesErrorInLogRecord() {
        enum TestError: Error {
            case boom
        }

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

        logger.info(.stub, error: TestError.boom, file: "file", function: "function", line: 42)

        XCTAssertEqual(processor.records, [
            .stub(
                metadata: ["code.file.path": "file", "code.function.name": "function", "code.line.number": "42"],
                error: TestError.boom,
                resource: resource
            ),
        ])
    }
}

extension OTelLogRecord: Equatable {
    static func == (lhs: OTelLogRecord, rhs: OTelLogRecord) -> Bool {
        lhs.body == rhs.body
            && lhs.level == rhs.level
            && lhs.metadata == rhs.metadata
            && errorsEqual(lhs.error, rhs.error)
            && lhs.timeNanosecondsSinceEpoch == rhs.timeNanosecondsSinceEpoch
            && lhs.resource == rhs.resource
            && lhs.spanContext == rhs.spanContext
    }
}

private func errorsEqual(_ lhs: (any Error)?, _ rhs: (any Error)?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
        return true
    case (let l?, let r?):
        return "\(l)" == "\(r)" && String(reflecting: type(of: l)) == String(reflecting: type(of: r))
    default:
        return false
    }
}

extension Logger.Message {
    fileprivate static let stub: Logger.Message = "🏎️"
}

extension OTelLogRecord {
    fileprivate static func stub(
        metadata: Logger.Metadata = [:],
        error: (any Error)? = nil,
        resource: OTelResource = OTelResource()
    ) -> OTelLogRecord {
        OTelLogRecord(
            body: .stub,
            level: .info,
            metadata: metadata,
            error: error,
            timeNanosecondsSinceEpoch: 42,
            resource: resource,
            spanContext: nil
        )
    }
}

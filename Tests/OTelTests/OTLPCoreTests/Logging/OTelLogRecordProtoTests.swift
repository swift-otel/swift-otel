//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2026 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import OTel
import XCTest

final class OTelLogRecordProtoTests: XCTestCase {
    func test_initProtoResourceLogs_groupsLogRecordsByInstrumentationScope() {
        let logRecords: [OTelLogRecord] = [
            .stub(body: "1", instrumentationScopeName: "A"),
            .stub(body: "2", instrumentationScopeName: "B"),
            .stub(body: "3", instrumentationScopeName: "A"),
        ]

        let resourceLogs = Opentelemetry_Proto_Logs_V1_ResourceLogs(logRecords)

        XCTAssertEqual(resourceLogs.scopeLogs.map(\.scope), [
            .with { $0.name = "A" },
            .with { $0.name = "B" },
        ])
        XCTAssertEqual(
            resourceLogs.scopeLogs.map { $0.logRecords.map(\.body.stringValue) },
            [["1", "3"], ["2"]]
        )
    }
}

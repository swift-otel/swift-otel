//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2025 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import Testing

@testable import OTel

@Suite struct DiagnosticLoggingTests {
    @Test(arguments: Logger.Level.allCases) func testLogErrorHelper(level: Logger.Level) async throws {
        let recordingHandler = RecordingLogHandler()
        var logMessages = recordingHandler.recordedLogMessageStream.makeAsyncIterator()
        let logger = Logger(label: "test") { _ in recordingHandler }
        struct TestError: Error, CustomStringConvertible {
            var description: String { "custom description" }
        }

        logger.log(level: level, error: TestError(), message: "Thing failed.", metadata: ["foo": "bar"])
        let message = await logMessages.next()
        #expect(message?.level == level)
        #expect(message?.message == "Thing failed.")
        #expect(message?.metadata?["foo"] == "bar")
        #expect(message?.metadata?["error"] == "custom description")
        #expect(message?.metadata?["error_type"] == "TestError")
    }
}

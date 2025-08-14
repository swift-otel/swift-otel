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
@testable import OTel
import Testing

@Suite struct DiagnosticLoggingTests {
    @Test func testLogErrorHelper() async throws {
        let recordingHandler = RecordingLogHandler()
        var logMessages = recordingHandler.recordedLogMessageStream.makeAsyncIterator()
        let logger = Logger(label: "test") { _ in recordingHandler }
        struct TestError: Error, CustomStringConvertible {
            var description: String { "custom description" }
        }

        for level in [Logger.Level.trace, .trace, .info, .warning, .error] {
            logger.log(level: level, error: TestError(), message: "Thing failed.")
            let message = await logMessages.next()
            #expect(message?.level == level)
            #expect(message?.message == "Thing failed.")
            #expect(message?.metadata?["error"] == "custom description")
            #expect(message?.metadata?["error_type"] == "TestError")
        }
    }
}

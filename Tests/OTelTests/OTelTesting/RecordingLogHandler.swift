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

package import Logging
package import NIOConcurrencyHelpers

package struct RecordingLogHandler: LogHandler {
    package typealias LogFunctionCall = (level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?)

    private let _level = NIOLockedValueBox(Logger.Level.trace)
    private let _metadata = NIOLockedValueBox(Logger.Metadata())
    package let recordedLogMessages = NIOLockedValueBox([LogFunctionCall]())
    let recordedLogMessageStream: AsyncStream<LogFunctionCall>
    let recordedLogMessageContinuation: AsyncStream<LogFunctionCall>.Continuation
    package let counts = NIOLockedValueBox([Logger.Level: Int]())

    package init() {
        (recordedLogMessageStream, recordedLogMessageContinuation) = AsyncStream<LogFunctionCall>.makeStream()
    }

    package func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        recordedLogMessages.withLockedValue { $0.append((level, message, metadata)) }
        counts.withLockedValue { $0[level] = $0[level, default: 0] + 1 }
        recordedLogMessageContinuation.yield((level, message, metadata))
    }

    package var metadata: Logging.Logger.Metadata {
        get { self._metadata.withLockedValue { $0 } }
        set(newValue) { self._metadata.withLockedValue { $0 = newValue } }
    }

    package var logLevel: Logging.Logger.Level {
        get { self._level.withLockedValue { $0 } }
        set(newValue) { self._level.withLockedValue { $0 = newValue } }
    }

    package subscript(metadataKey metadataKey: String) -> Logging.Logger.Metadata.Value? {
        get { _metadata.withLockedValue { $0[metadataKey] } }
        set(newValue) { _metadata.withLockedValue { $0[metadataKey] = newValue } }
    }
}

extension RecordingLogHandler {
    package var warningCount: Int {
        counts.withLockedValue { $0[.warning, default: 0] }
    }

    package var errorCount: Int {
        counts.withLockedValue { $0[.error, default: 0] }
    }
}

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

import Logging
import NIOConcurrencyHelpers

struct RecordingLogHandler: LogHandler {
    typealias LogFunctionCall = (level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?)

    private let _level = NIOLockedValueBox(Logger.Level.trace)
    private let _metadata = NIOLockedValueBox(Logger.Metadata())
    let recordedLogMessages = NIOLockedValueBox([LogFunctionCall]())
    let recordedLogMessageStream: AsyncStream<LogFunctionCall>
    let recordedLogMessageContinuation: AsyncStream<LogFunctionCall>.Continuation
    let counts = NIOLockedValueBox([Logger.Level: Int]())

    init() {
        (recordedLogMessageStream, recordedLogMessageContinuation) = AsyncStream<LogFunctionCall>.makeStream()
    }

    func log(event: LogEvent) {
        let metadata = self.metadata.merging(event.metadata ?? [:], uniquingKeysWith: { _, new in new })
        recordedLogMessages.withLockedValue { $0.append((event.level, event.message, metadata)) }
        counts.withLockedValue { $0[event.level] = $0[event.level, default: 0] + 1 }
        recordedLogMessageContinuation.yield((event.level, event.message, metadata))
    }

    var metadata: Logging.Logger.Metadata {
        get { _metadata.withLockedValue { $0 } }
        set(newValue) { _metadata.withLockedValue { $0 = newValue } }
    }

    var logLevel: Logging.Logger.Level {
        get { _level.withLockedValue { $0 } }
        set(newValue) { _level.withLockedValue { $0 = newValue } }
    }

    subscript(metadataKey metadataKey: String) -> Logging.Logger.Metadata.Value? {
        get { _metadata.withLockedValue { $0[metadataKey] } }
        set(newValue) { _metadata.withLockedValue { $0[metadataKey] = newValue } }
    }
}

extension RecordingLogHandler {
    var warningCount: Int {
        counts.withLockedValue { $0[.warning, default: 0] }
    }

    var errorCount: Int {
        counts.withLockedValue { $0[.error, default: 0] }
    }
}

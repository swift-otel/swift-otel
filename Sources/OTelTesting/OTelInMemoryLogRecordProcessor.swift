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

import NIOConcurrencyHelpers
import OTelCore

/// An in-memory log record processor, collecting emitted log records into ``onEmit(_:)``.
package final class OTelInMemoryLogRecordProcessor: OTelLogRecordProcessor {
    package var records: [OTelLogRecord] { _records.withLockedValue { $0 } }
    private let _records = NIOLockedValueBox<[OTelLogRecord]>([])

    package var numberOfShutdowns: Int { _numberOfShutdowns.withLockedValue { $0 } }
    private let _numberOfShutdowns = NIOLockedValueBox<Int>(0)

    package var numberOfForceFlushes: Int { _numberOfForceFlushes.withLockedValue { $0 } }
    private let _numberOfForceFlushes = NIOLockedValueBox<Int>(0)

    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    package init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    package func run() async throws {
        for await _ in stream.cancelOnGracefulShutdown() {}
        _numberOfShutdowns.withLockedValue { $0 += 1 }
    }

    package nonisolated func onEmit(_ record: inout OTelLogRecord) {
        _records.withLockedValue { $0.append(record) }
    }

    package func forceFlush() async throws {
        _numberOfForceFlushes.withLockedValue { $0 += 1 }
    }
}

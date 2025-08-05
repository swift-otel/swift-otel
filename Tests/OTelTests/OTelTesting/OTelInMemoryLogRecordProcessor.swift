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
@testable import OTel
import ServiceLifecycle

/// An in-memory log record processor, collecting emitted log records into ``onEmit(_:)``.
final class OTelInMemoryLogRecordProcessor: OTelLogRecordProcessor {
    var records: [OTelLogRecord] { _records.withLockedValue { $0 } }
    private let _records = NIOLockedValueBox<[OTelLogRecord]>([])

    var numberOfShutdowns: Int { _numberOfShutdowns.withLockedValue { $0 } }
    private let _numberOfShutdowns = NIOLockedValueBox<Int>(0)

    var numberOfForceFlushes: Int { _numberOfForceFlushes.withLockedValue { $0 } }
    private let _numberOfForceFlushes = NIOLockedValueBox<Int>(0)

    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    func run() async throws {
        await withGracefulShutdownHandler {
            for await _ in stream.cancelOnGracefulShutdown() {}
        } onGracefulShutdown: {
            self.continuation.finish()
        }
        _numberOfShutdowns.withLockedValue { $0 += 1 }
    }

    nonisolated func onEmit(_ record: inout OTelLogRecord) {
        _records.withLockedValue { $0.append(record) }
    }

    func forceFlush() async throws {
        _numberOfForceFlushes.withLockedValue { $0 += 1 }
    }
}

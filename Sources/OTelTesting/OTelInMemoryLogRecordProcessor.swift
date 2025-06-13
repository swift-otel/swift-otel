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
@_spi(Logging) import OTelCore

/// An in-memory log record processor, collecting emitted log records into ``onEmit(_:)``.
@_spi(Logging)
public final class OTelInMemoryLogRecordProcessor: OTelLogRecordProcessor {
    public var records: [OTelLogRecord] { _records.withLockedValue { $0 } }
    private let _records = NIOLockedValueBox<[OTelLogRecord]>([])

    public var numberOfShutdowns: Int { _numberOfShutdowns.withLockedValue { $0 } }
    private let _numberOfShutdowns = NIOLockedValueBox<Int>(0)

    public var numberOfForceFlushes: Int { _numberOfForceFlushes.withLockedValue { $0 } }
    private let _numberOfForceFlushes = NIOLockedValueBox<Int>(0)

    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    public init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    public func run() async throws {
        for await _ in stream.cancelOnGracefulShutdown() {}
        _numberOfShutdowns.withLockedValue { $0 += 1 }
    }

    public nonisolated func onEmit(_ record: inout OTelLogRecord) {
        _records.withLockedValue { $0.append(record) }
    }

    public func forceFlush() async throws {
        _numberOfForceFlushes.withLockedValue { $0 += 1 }
    }
}

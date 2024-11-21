//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2024 Moritz Lang and the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ServiceContextModule
import ServiceLifecycle

/// A pseudo-``OTelLogEntryProcessor`` that may be used to process using multiple other ``OTelLogEntryProcessor``s.
@_spi(Logging)
public actor OTelMultiplexLogEntryProcessor: OTelLogRecordProcessor {
    private let processors: [any OTelLogRecordProcessor]
    private let shutdownStream: AsyncStream<Void>
    private let shutdownContinuation: AsyncStream<Void>.Continuation

    /// Create an ``OTelMultiplexLogEntryProcessor``.
    ///
    /// - Parameter processors: An array of ``OTelLogEntryProcessor``s, each of which will be invoked on log events
    /// Processors are called sequentially and the order of this array defines the order in which they're being called.
    public init(processors: [any OTelLogRecordProcessor]) {
        self.processors = processors
        (shutdownStream, shutdownContinuation) = AsyncStream.makeStream()
    }

    public func run() async throws {
        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                var shutdowns = self.shutdownStream.makeAsyncIterator()
                await shutdowns.next()
                throw CancellationError()
            }

            for processor in processors {
                group.addTask { try await processor.run() }
            }

            await withGracefulShutdownHandler {
                try? await group.next()
                group.cancelAll()
            } onGracefulShutdown: {
                self.shutdownContinuation.yield()
            }
        }
    }

    nonisolated public func onEmit(_ record: inout OTelLogRecord) {
        for processor in processors {
            processor.onEmit(&record)
        }
    }

    public func forceFlush() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for processor in processors {
                group.addTask { try await processor.forceFlush() }
            }

            try await group.waitForAll()
        }
    }
}

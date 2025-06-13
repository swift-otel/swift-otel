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

import ServiceContextModule
import ServiceLifecycle

/// A pseudo-``OTelSpanProcessor`` that may be used to process using multiple other ``OTelSpanProcessor``s.
public actor OTelMultiplexSpanProcessor: OTelSpanProcessor {
    private let processors: [any OTelSpanProcessor]
    private let shutdownStream: AsyncStream<Void>
    private let shutdownContinuation: AsyncStream<Void>.Continuation

    /// Create an ``OTelMultiplexSpanProcessor``.
    ///
    /// - Parameter processors: An array of ``OTelSpanProcessor``s, each of which will be invoked on start and end of spans.
    /// Processors are called sequentially and the order of this array defines the order in which they're being called.
    public init(processors: [any OTelSpanProcessor]) {
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

    public func onStart(_ span: OTelSpan, parentContext: ServiceContext) async {
        for processor in processors {
            await processor.onStart(span, parentContext: parentContext)
        }
    }

    public func onEnd(_ span: OTelFinishedSpan) async {
        for processor in processors {
            await processor.onEnd(span)
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

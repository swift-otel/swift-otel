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

@testable import OTel
import ServiceContextModule
import ServiceLifecycle

/// An in-memory span processor, collecting started spans into ``OTelInMemorySpanProcessor/startedSpans``
/// and finished spans into ``OTelInMemorySpanProcessor/finishedSpans``.
final actor OTelInMemorySpanProcessor: OTelSpanProcessor {
    private(set) var startedSpans = [(span: OTelSpan, parentContext: ServiceContext)]()
    private(set) var finishedSpans = [OTelFinishedSpan]()
    private(set) var numberOfForceFlushes = 0
    private(set) var numberOfShutdowns = 0

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
        numberOfShutdowns += 1
    }

    func onStart(_ span: OTelSpan, parentContext: ServiceContext) async {
        startedSpans.append((span, parentContext))
    }

    func onEnd(_ span: OTelFinishedSpan) async {
        finishedSpans.append(span)
    }

    func forceFlush() async throws {
        numberOfForceFlushes += 1
    }
}

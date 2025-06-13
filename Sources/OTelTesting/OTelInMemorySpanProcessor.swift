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

import OTelCore
import ServiceContextModule

/// An in-memory span processor, collecting started spans into ``OTelInMemorySpanProcessor/startedSpans``
/// and finished spans into ``OTelInMemorySpanProcessor/finishedSpans``.
package final actor OTelInMemorySpanProcessor: OTelSpanProcessor {
    package private(set) var startedSpans = [(span: OTelSpan, parentContext: ServiceContext)]()
    package private(set) var finishedSpans = [OTelFinishedSpan]()
    package private(set) var numberOfForceFlushes = 0
    package private(set) var numberOfShutdowns = 0

    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    package init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    package func run() async throws {
        for await _ in stream.cancelOnGracefulShutdown() {}
        numberOfShutdowns += 1
    }

    package func onStart(_ span: OTelSpan, parentContext: ServiceContext) async {
        startedSpans.append((span, parentContext))
    }

    package func onEnd(_ span: OTelFinishedSpan) async {
        finishedSpans.append(span)
    }

    package func forceFlush() async throws {
        numberOfForceFlushes += 1
    }
}

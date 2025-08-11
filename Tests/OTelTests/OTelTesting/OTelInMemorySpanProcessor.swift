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
import ServiceContextModule
import ServiceLifecycle

/// An in-memory span processor, collecting started spans into ``OTelInMemorySpanProcessor/startedSpans``
/// and finished spans into ``OTelInMemorySpanProcessor/finishedSpans``.
final class OTelInMemorySpanProcessor: OTelSpanProcessor {
    var startedSpans: [(span: OTelSpan, parentContext: ServiceContext)] { _startedSpans.withLockedValue { $0 } }
    private let _startedSpans = NIOLockedValueBox<[(span: OTelSpan, parentContext: ServiceContext)]>([])

    var finishedSpans: [OTelFinishedSpan] { _finishedSpans.withLockedValue { $0 } }
    private let _finishedSpans = NIOLockedValueBox<[OTelFinishedSpan]>([])

    var numberOfShutdowns: Int { _numberOfShutdowns.withLockedValue { $0 } }
    private let _numberOfShutdowns = NIOLockedValueBox<Int>(0)

    var numberOfForceFlushes: Int { _numberOfForceFlushes.withLockedValue { $0 } }
    private let _numberOfForceFlushes = NIOLockedValueBox<Int>(0)

    init() {}

    func run() async throws {
        try await withGracefulShutdownHandler {
            try await gracefulShutdown()
        } onGracefulShutdown: {
            self._numberOfShutdowns.withLockedValue { $0 += 1 }
        }
    }

    nonisolated func onStart(_ span: OTelSpan, parentContext: ServiceContext) {
        _startedSpans.withLockedValue { $0.append((span, parentContext)) }
    }

    nonisolated func onEnd(_ span: OTelFinishedSpan) {
        _finishedSpans.withLockedValue { $0.append(span) }
    }

    func forceFlush() async throws {
        _numberOfForceFlushes.withLockedValue { $0 += 1 }
    }
}

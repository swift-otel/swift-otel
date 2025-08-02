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

/// A span exporter, streaming exported batches via an async sequence.
final actor OTelStreamingSpanExporter: OTelSpanExporter {
    let batches: AsyncStream<[OTelFinishedSpan]>
    private let batchContinuation: AsyncStream<[OTelFinishedSpan]>.Continuation
    private var errorDuringNextExport: (any Error)?

    private(set) var numberOfShutdowns = 0
    private(set) var numberOfForceFlushes = 0

    init() {
        (batches, batchContinuation) = AsyncStream<[OTelFinishedSpan]>.makeStream()
    }

    func setErrorDuringNextExport(_ error: some Error) {
        errorDuringNextExport = error
    }

    func run() async throws {}

    func export(_ batch: some Collection<OTelFinishedSpan>) async throws {
        batchContinuation.yield(Array(batch))
        if let errorDuringNextExport {
            self.errorDuringNextExport = nil
            throw errorDuringNextExport
        }
    }

    func shutdown() async {
        numberOfShutdowns += 1
    }

    func forceFlush() async throws {
        numberOfForceFlushes += 1
    }
}

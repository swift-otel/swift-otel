//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2025 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import OTel

/// A log record exporter streaming exported batches via an async sequence.
final actor OTelStreamingLogRecordExporter: OTelLogRecordExporter {
    let batches: AsyncStream<[OTelLogRecord]>
    private let batchContinuation: AsyncStream<[OTelLogRecord]>.Continuation
    private var errorDuringNextExport: (any Error)?

    private(set) var numberOfShutdowns = 0
    private(set) var numberOfForceFlushes = 0

    init() {
        (batches, batchContinuation) = AsyncStream<[OTelLogRecord]>.makeStream()
    }

    func run() async {
        // No background work needed, but we'll keep the run method running until its cancelled.
        await AsyncStream.makeStream(of: Void.self).stream.cancelOnGracefulShutdown().first { _ in true }
    }

    func setErrorDuringNextExport(_ error: some Error) {
        errorDuringNextExport = error
    }

    func export(_ batch: some Collection<OTelLogRecord>) async throws {
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

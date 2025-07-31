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

@testable package import OTel

/// A log record exporter streaming exported batches via an async sequence.
package final actor OTelStreamingLogRecordExporter: OTelLogRecordExporter {
    package let batches: AsyncStream<[OTelLogRecord]>
    private let batchContinuation: AsyncStream<[OTelLogRecord]>.Continuation
    private var errorDuringNextExport: (any Error)?

    package private(set) var numberOfShutdowns = 0
    package private(set) var numberOfForceFlushes = 0

    package init() {
        (batches, batchContinuation) = AsyncStream<[OTelLogRecord]>.makeStream()
    }

    package func run() async throws {}

    package func setErrorDuringNextExport(_ error: some Error) {
        errorDuringNextExport = error
    }

    package func export(_ batch: some Collection<OTelLogRecord>) async throws {
        batchContinuation.yield(Array(batch))
        if let errorDuringNextExport {
            self.errorDuringNextExport = nil
            throw errorDuringNextExport
        }
    }

    package func shutdown() async {
        numberOfShutdowns += 1
    }

    package func forceFlush() async throws {
        numberOfForceFlushes += 1
    }
}

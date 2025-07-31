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

package import OTelCore

/// A span exporter, streaming exported batches via an async sequence.
package final actor OTelStreamingSpanExporter: OTelSpanExporter {
    package let batches: AsyncStream<[OTelFinishedSpan]>
    private let batchContinuation: AsyncStream<[OTelFinishedSpan]>.Continuation
    private var errorDuringNextExport: (any Error)?

    package private(set) var numberOfShutdowns = 0
    package private(set) var numberOfForceFlushes = 0

    package init() {
        (batches, batchContinuation) = AsyncStream<[OTelFinishedSpan]>.makeStream()
    }

    package func setErrorDuringNextExport(_ error: some Error) {
        errorDuringNextExport = error
    }

    package func run() async throws {}

    package func export(_ batch: some Collection<OTelFinishedSpan>) async throws {
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

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

/// A span exporter, streaming exported batches via an async sequence.
public final actor OTelStreamingSpanExporter: OTelSpanExporter {
    public let batches: AsyncStream<[OTelFinishedSpan]>
    private let batchContinuation: AsyncStream<[OTelFinishedSpan]>.Continuation
    private var errorDuringNextExport: (any Error)?

    public private(set) var numberOfShutdowns = 0
    public private(set) var numberOfForceFlushes = 0

    public init() {
        (batches, batchContinuation) = AsyncStream<[OTelFinishedSpan]>.makeStream()
    }

    public func setErrorDuringNextExport(_ error: some Error) {
        errorDuringNextExport = error
    }

    public func export(_ batch: some Collection<OTelFinishedSpan>) async throws {
        batchContinuation.yield(Array(batch))
        if let errorDuringNextExport {
            self.errorDuringNextExport = nil
            throw errorDuringNextExport
        }
    }

    public func shutdown() async {
        numberOfShutdowns += 1
    }

    public func forceFlush() async throws {
        numberOfForceFlushes += 1
    }
}

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

@_spi(Logging) import OTel

/// A log record exporter streaming exported batches via an async sequence.
@_spi(Logging)
public final actor OTelStreamingLogRecordExporter: OTelLogRecordExporter {
    public let batches: AsyncStream<[OTelLogRecord]>
    private let batchContinuation: AsyncStream<[OTelLogRecord]>.Continuation
    private var errorDuringNextExport: (any Error)?

    public private(set) var numberOfShutdowns = 0
    public private(set) var numberOfForceFlushes = 0

    public init() {
        (batches, batchContinuation) = AsyncStream<[OTelLogRecord]>.makeStream()
    }

    public func setErrorDuringNextExport(_ error: some Error) {
        errorDuringNextExport = error
    }

    public func export(_ batch: some Collection<OTelLogRecord>) async throws {
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

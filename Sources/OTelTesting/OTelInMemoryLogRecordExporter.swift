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
@_spi(Logging) import OTel

@_spi(Logging)
public actor OTelInMemoryLogRecordExporter: OTelLogRecordExporter {
    public private(set) var exportedBatches = [[OTelLogRecord]]()
    public private(set) var numberOfShutdowns = 0
    public private(set) var numberOfForceFlushes = 0
    public nonisolated let (didRecordBatch, recordContinuation) = AsyncStream<Int>.makeStream()

    public init() {}

    public func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws {
        exportedBatches.append(Array(batch))
        recordContinuation.yield(batch.count)
    }

    public func forceFlush() async throws {
        numberOfForceFlushes += 1
    }

    public func shutdown() async {
        numberOfShutdowns += 1
    }
}

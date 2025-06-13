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
@_spi(Logging) import OTelCore

@_spi(Logging)
public actor OTelInMemoryLogRecordExporter: OTelLogRecordExporter {
    public private(set) var exportedBatches = [[OTelLogRecord]]()
    public private(set) var numberOfShutdowns = 0
    public private(set) var numberOfForceFlushes = 0
    public private(set) var numberOfExportCancellations = 0

    private let exportDelay: Duration

    public init(exportDelay: Duration = .zero) {
        self.exportDelay = exportDelay
    }

    public func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws {
        if exportDelay != .zero {
            do {
                try await Task.sleep(for: exportDelay)
            } catch let error as CancellationError {
                numberOfExportCancellations += 1
                throw error
            }
        }

        exportedBatches.append(Array(batch))
    }

    public func forceFlush() async throws {
        numberOfForceFlushes += 1
    }

    public func shutdown() async {
        numberOfShutdowns += 1
    }
}

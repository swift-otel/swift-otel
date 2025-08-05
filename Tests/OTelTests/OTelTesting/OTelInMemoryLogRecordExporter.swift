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
import ServiceLifecycle

actor OTelInMemoryLogRecordExporter: OTelLogRecordExporter {
    private(set) var exportedBatches = [[OTelLogRecord]]()
    private(set) var numberOfShutdowns = 0
    private(set) var numberOfForceFlushes = 0
    private(set) var numberOfExportCancellations = 0

    private let exportDelay: Duration

    init(exportDelay: Duration = .zero) {
        self.exportDelay = exportDelay
    }

    func run() async throws {
        // No background work needed, but we'll keep the run method running until its cancelled.
        try await gracefulShutdown()
    }

    func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws {
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

    func forceFlush() async throws {
        numberOfForceFlushes += 1
    }

    func shutdown() async {
        numberOfShutdowns += 1
    }
}

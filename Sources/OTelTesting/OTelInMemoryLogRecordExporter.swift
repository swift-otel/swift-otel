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
import OTelCore

package actor OTelInMemoryLogRecordExporter: OTelLogRecordExporter {
    package private(set) var exportedBatches = [[OTelLogRecord]]()
    package private(set) var numberOfShutdowns = 0
    package private(set) var numberOfForceFlushes = 0
    package private(set) var numberOfExportCancellations = 0

    private let exportDelay: Duration

    package init(exportDelay: Duration = .zero) {
        self.exportDelay = exportDelay
    }

    package func run() async throws {}

    package func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws {
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

    package func forceFlush() async throws {
        numberOfForceFlushes += 1
    }

    package func shutdown() async {
        numberOfShutdowns += 1
    }
}

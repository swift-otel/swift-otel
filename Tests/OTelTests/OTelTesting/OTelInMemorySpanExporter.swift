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

/// An in-memory span exporter, collecting exported batches into ``OTelInMemorySpanExporter/exportedBatches``.
package final actor OTelInMemorySpanExporter: OTelSpanExporter {
    package private(set) var exportedBatches = [[OTelFinishedSpan]]()
    package private(set) var numberOfShutdowns = 0
    package private(set) var numberOfForceFlushes = 0

    private let exportDelay: Duration

    package init(exportDelay: Duration = .zero) {
        self.exportDelay = exportDelay
    }

    package func run() async throws {
        // no-op
    }

    package func export(_ batch: some Collection<OTelFinishedSpan>) async throws {
        if exportDelay != .zero {
            try await Task.sleep(for: exportDelay)
        }
        exportedBatches.append(Array(batch))
    }

    package func shutdown() async {
        numberOfShutdowns += 1
    }

    package func forceFlush() async throws {
        numberOfForceFlushes += 1
    }
}

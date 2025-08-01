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

@testable import OTel

/// An in-memory span exporter, collecting exported batches into ``OTelInMemorySpanExporter/exportedBatches``.
final actor OTelInMemorySpanExporter: OTelSpanExporter {
    private(set) var exportedBatches = [[OTelFinishedSpan]]()
    private(set) var numberOfShutdowns = 0
    private(set) var numberOfForceFlushes = 0

    private let exportDelay: Duration

    init(exportDelay: Duration = .zero) {
        self.exportDelay = exportDelay
    }

    func run() async throws {
        // no-op
    }

    func export(_ batch: some Collection<OTelFinishedSpan>) async throws {
        if exportDelay != .zero {
            try await Task.sleep(for: exportDelay)
        }
        exportedBatches.append(Array(batch))
    }

    func shutdown() async {
        numberOfShutdowns += 1
    }

    func forceFlush() async throws {
        numberOfForceFlushes += 1
    }
}

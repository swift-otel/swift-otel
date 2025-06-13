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

/// An in-memory span exporter, collecting exported batches into ``OTelInMemorySpanExporter/exportedBatches``.
public final actor OTelInMemorySpanExporter: OTelSpanExporter {
    public private(set) var exportedBatches = [[OTelFinishedSpan]]()
    public private(set) var numberOfShutdowns = 0
    public private(set) var numberOfForceFlushes = 0

    private let exportDelay: Duration

    public init(exportDelay: Duration = .zero) {
        self.exportDelay = exportDelay
    }

    public func export(_ batch: some Collection<OTelFinishedSpan>) async throws {
        if exportDelay != .zero {
            try await Task.sleep(for: exportDelay)
        }
        exportedBatches.append(Array(batch))
    }

    public func shutdown() async {
        numberOfShutdowns += 1
    }

    public func forceFlush() async throws {
        numberOfForceFlushes += 1
    }
}

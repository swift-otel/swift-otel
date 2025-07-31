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

/// A pseudo-``OTelSpanExporter`` that may be used to export using multiple other ``OTelSpanExporter``s.
package struct OTelMultiplexSpanExporter: OTelSpanExporter {
    private let exporters: [any OTelSpanExporter]

    /// Initialize an ``OTelMultiplexSpanExporter``.
    ///
    /// - Parameter exporters: An array of ``OTelSpanExporter``s, each of which will receive the exported batches.
    package init(exporters: [any OTelSpanExporter]) {
        self.exporters = exporters
    }

    package func run() async throws {
        try await withThrowingTaskGroup { group in
            for exporter in exporters {
                group.addTask {
                    try await exporter.run()
                }
            }
            try await group.waitForAll()
        }
    }

    package func export(_ batch: some Collection<OTelFinishedSpan> & Sendable) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for exporter in exporters {
                group.addTask { try await exporter.export(batch) }
            }

            try await group.waitForAll()
        }
    }

    package func forceFlush() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for exporter in exporters {
                group.addTask { try await exporter.forceFlush() }
            }

            try await group.waitForAll()
        }
    }

    package func shutdown() async {
        await withTaskGroup(of: Void.self) { group in
            for exporter in exporters {
                group.addTask { await exporter.shutdown() }
            }

            await group.waitForAll()
        }
    }
}

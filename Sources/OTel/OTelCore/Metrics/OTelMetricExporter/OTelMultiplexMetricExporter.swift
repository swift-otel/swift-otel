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

/// A metric exporter that delegates to multiple other exports.
struct OTelMultiplexMetricExporter: OTelMetricExporter {
    private let exporters: [any OTelMetricExporter]

    /// Initialize an ``OTelMultiplexMetricExporter``.
    ///
    /// - Parameter exporters: An array of ``OTelMetricExporter``s, each of which will receive the batches to export.
    init(exporters: [any OTelMetricExporter]) {
        self.exporters = exporters
    }

    func run() async throws {
        try await withThrowingTaskGroup { group in
            for exporter in exporters {
                group.addTask {
                    try await exporter.run()
                }
            }
            try await group.waitForAll()
        }
    }

    func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for exporter in exporters {
                group.addTask { try await exporter.export(batch) }
            }
            try await group.waitForAll()
        }
    }

    func forceFlush() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for exporter in exporters {
                group.addTask { try await exporter.forceFlush() }
            }
            try await group.waitForAll()
        }
    }

    func shutdown() async {
        await withTaskGroup(of: Void.self) { group in
            for exporter in exporters {
                group.addTask { await exporter.shutdown() }
            }
            await group.waitForAll()
        }
    }
}

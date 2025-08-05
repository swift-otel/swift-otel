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

import ServiceLifecycle

/// A metric exporter that logs metrics to the console for debugging.
struct OTelConsoleMetricExporter: OTelMetricExporter {
    /// Create a new ``OTelConsoleMetricExporter``.

    func run() async throws {
        // No background work needed, but we'll keep the run method running until its cancelled.
        try await gracefulShutdown()
    }

    func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws {
        for metric in batch {
            print(metric)
        }
    }

    func forceFlush() async throws {}

    func shutdown() async {}
}

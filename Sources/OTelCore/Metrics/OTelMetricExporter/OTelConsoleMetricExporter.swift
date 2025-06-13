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

/// A metric exporter that logs metrics to the console for debugging.
package struct OTelConsoleMetricExporter: OTelMetricExporter {
    /// Create a new ``OTelConsoleMetricExporter``.
    package init() {}

    package func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws {
        for metric in batch {
            print(metric)
        }
    }

    package func forceFlush() async throws {}

    package func shutdown() async {}
}

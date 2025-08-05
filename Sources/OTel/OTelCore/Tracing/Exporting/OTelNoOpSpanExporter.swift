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

/// A span exporter that ignores all operations, used when no spans should be exported.
struct OTelNoOpSpanExporter: OTelSpanExporter {
    /// Initialize a no-op span exporter.

    func run() async throws {
        // No background work needed, but we'll keep the run method running until its cancelled.
        try await gracefulShutdown()
    }

    func export(_ batch: some Collection<OTelFinishedSpan>) async throws {
        // no-op
    }

    func forceFlush() async throws {
        // no-op
    }

    func shutdown() async {
        // no-op
    }
}

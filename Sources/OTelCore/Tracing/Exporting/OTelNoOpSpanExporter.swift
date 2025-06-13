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

/// A span exporter that ignores all operations, used when no spans should be exported.
package struct OTelNoOpSpanExporter: OTelSpanExporter {
    /// Initialize a no-op span exporter.
    package init() {}

    package func export(_ batch: some Collection<OTelFinishedSpan>) async throws {
        // no-op
    }

    package func forceFlush() async throws {
        // no-op
    }

    package func shutdown() async {
        // no-op
    }
}

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2024 Moritz Lang and the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOConcurrencyHelpers
@_spi(Logging) import OTel

package final class OTelInMemoryLogRecordExporter: OTelLogRecordExporter {
    private let _records = NIOLockedValueBox([OTelLogRecord]())
    package let (didExportBatch, continuation) = AsyncStream<Void>.makeStream()
    package var records: [OTelLogRecord] { _records.withLockedValue { $0 } }

    package init() {}

    package func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws {
        _records.withLockedValue { $0.append(contentsOf: batch) }
        continuation.yield()
    }

    package func forceFlush() async throws {
        continuation.yield()
    }

    package func shutdown() async {
        continuation.finish()
    }
}

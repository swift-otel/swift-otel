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
    package var records: [OTelLogRecord] { _records.withLockedValue { $0 } }

    package init() {}

    package func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws {
        _records.withLockedValue { $0.append(contentsOf: batch) }
    }

    package func forceFlush() async throws {
        // NO-OP
    }

    package func shutdown() async {
        // NO-OP
    }
}

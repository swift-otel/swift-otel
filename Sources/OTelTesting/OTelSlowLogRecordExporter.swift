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

import NIOConcurrencyHelpers
@_spi(Logging) import OTel

package final class OTelSlowLogRecordExporter<Clock: _Concurrency.Clock<Duration>>: OTelLogRecordExporter {
    private let _records = NIOLockedValueBox([OTelLogRecord]())
    package var records: [OTelLogRecord] { _records.withLockedValue { $0 } }

    private let _cancelCount = NIOLockedValueBox(0)
    package var cancelCount: Int { _cancelCount.withLockedValue { $0 } }
    let delay: Duration
    let clock: Clock

    package init(delay: Duration, clock: Clock) {
        self.delay = delay
        self.clock = clock
    }

    package func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws {
        do {
            try await Task.sleep(for: delay, clock: clock)
            _records.withLockedValue { $0.append(contentsOf: batch) }
        } catch is CancellationError {
            _cancelCount.withLockedValue { $0 += 1 }
            throw CancellationError()
        }
    }

    package func forceFlush() async throws {
        // NO-OP
    }

    package func shutdown() async {
        // NO-OP
    }
}

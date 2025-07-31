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

#if canImport(XCTest)
package import NIOConcurrencyHelpers
import XCTest
@testable package import OTel

package struct RecordingMetricExporter: OTelMetricExporter {
    package typealias ExportCall = Collection<OTelResourceMetrics> & Sendable

    package struct RecordedCalls {
        var exportCalls = [any ExportCall]()
        var forceFlushCallCount = 0
        var shutdownCallCount = 0
    }

    package let recordedCalls = NIOLockedValueBox(RecordedCalls())

    package init() {}

    package func run() async throws {}

    package func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) {
        recordedCalls.withLockedValue { $0.exportCalls.append(batch) }
    }

    package func forceFlush() {
        recordedCalls.withLockedValue { $0.forceFlushCallCount += 1 }
    }

    package func shutdown() {
        recordedCalls.withLockedValue { $0.shutdownCallCount += 1 }
    }
}

extension RecordingMetricExporter {
    package func assert(
        exportCallCount: Int,
        forceFlushCallCount: Int,
        shutdownCallCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let recordedCalls = recordedCalls.withLockedValue { $0 }
        XCTAssertEqual(recordedCalls.exportCalls.count, exportCallCount, "Unexpected export call count", file: file, line: line)
        XCTAssertEqual(recordedCalls.forceFlushCallCount, forceFlushCallCount, "Unexpected forceFlush call count", file: file, line: line)
        XCTAssertEqual(recordedCalls.shutdownCallCount, shutdownCallCount, "Unexpected shutdown call count", file: file, line: line)
    }
}
#endif

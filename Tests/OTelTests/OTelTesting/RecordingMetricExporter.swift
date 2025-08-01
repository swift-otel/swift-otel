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
import NIOConcurrencyHelpers
@testable import OTel
import XCTest

struct RecordingMetricExporter: OTelMetricExporter {
    typealias ExportCall = Collection<OTelResourceMetrics> & Sendable

    struct RecordedCalls {
        var exportCalls = [any ExportCall]()
        var forceFlushCallCount = 0
        var shutdownCallCount = 0
    }

    let recordedCalls = NIOLockedValueBox(RecordedCalls())

    func run() async throws {}

    func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) {
        recordedCalls.withLockedValue { $0.exportCalls.append(batch) }
    }

    func forceFlush() {
        recordedCalls.withLockedValue { $0.forceFlushCallCount += 1 }
    }

    func shutdown() {
        recordedCalls.withLockedValue { $0.shutdownCallCount += 1 }
    }
}

extension RecordingMetricExporter {
    func assert(
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

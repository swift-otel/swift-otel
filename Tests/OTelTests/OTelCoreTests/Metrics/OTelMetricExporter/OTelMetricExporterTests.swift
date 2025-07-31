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

@testable import OTel
import XCTest

final class OTelMetricExporterTests: XCTestCase {
    func test_MultiplexExporter_forwadsCallsToAllExporters() async throws {
        let recordingExporters = (1 ... 3).map { _ in RecordingMetricExporter() }
        let multiplexExporter = OTelMultiplexMetricExporter(
            exporters: recordingExporters + [OTelConsoleMetricExporter()]
        )

        recordingExporters.forEach { $0.assert(exportCallCount: 0, forceFlushCallCount: 0, shutdownCallCount: 0) }

        try await multiplexExporter.export([])
        try await multiplexExporter.export([OTelResourceMetrics(scopeMetrics: [])])
        recordingExporters.forEach { $0.assert(exportCallCount: 2, forceFlushCallCount: 0, shutdownCallCount: 0) }

        try await multiplexExporter.forceFlush()
        recordingExporters.forEach { $0.assert(exportCallCount: 2, forceFlushCallCount: 1, shutdownCallCount: 0) }

        await multiplexExporter.shutdown()
        recordingExporters.forEach { $0.assert(exportCallCount: 2, forceFlushCallCount: 1, shutdownCallCount: 1) }
    }
}

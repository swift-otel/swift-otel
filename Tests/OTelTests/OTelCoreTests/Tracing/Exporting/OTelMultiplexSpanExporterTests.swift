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

import XCTest

@testable import OTel

final class OTelMultiplexSpanExporterTests: XCTestCase {
    func test_export_forwardsBatchToAllExporters() async throws {
        let exporter1 = OTelInMemorySpanExporter()
        let exporter2 = OTelInMemorySpanExporter()
        let exporter = OTelMultiplexSpanExporter(exporters: [exporter1, exporter2])

        let batch: [OTelFinishedSpan] = [
            OTelFinishedSpan.stub(operationName: "span1"),
            OTelFinishedSpan.stub(operationName: "span2"),
        ]

        try await exporter.export(batch)

        let exporter1Batches = await exporter1.exportedBatches
        XCTAssertEqual(exporter1Batches.count, 1)
        let exporter1Batch = try XCTUnwrap(exporter1Batches.first)
        XCTAssertEqual(exporter1Batch.map(\.operationName), ["span1", "span2"])

        let exporter2Batches = await exporter2.exportedBatches
        XCTAssertEqual(exporter2Batches.count, 1)
        let exporter2Batch = try XCTUnwrap(exporter2Batches.first)
        XCTAssertEqual(exporter2Batch.map(\.operationName), ["span1", "span2"])
    }

    func test_forceFlush_forceFlushesAllExporters() async throws {
        let exporter1 = OTelInMemorySpanExporter()
        let exporter2 = OTelInMemorySpanExporter()
        let exporter = OTelMultiplexSpanExporter(exporters: [exporter1, exporter2])

        try await exporter.forceFlush()

        let exporter1ForceFlushCount = await exporter1.numberOfForceFlushes
        XCTAssertEqual(exporter1ForceFlushCount, 1)

        let exporter2ForceFlushCount = await exporter2.numberOfForceFlushes
        XCTAssertEqual(exporter2ForceFlushCount, 1)
    }

    func test_shutdown_shutsDownAllExporters() async {
        let exporter1 = OTelInMemorySpanExporter()
        let exporter2 = OTelInMemorySpanExporter()
        let exporter = OTelMultiplexSpanExporter(exporters: [exporter1, exporter2])

        await exporter.shutdown()

        let exporter1ShutdownCount = await exporter1.numberOfShutdowns
        XCTAssertEqual(exporter1ShutdownCount, 1)

        let exporter2ShutdownCount = await exporter2.numberOfShutdowns
        XCTAssertEqual(exporter2ShutdownCount, 1)
    }
}

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
import XCTest

@testable import OTel

final class OTelSimpleSpanProcessorTests: XCTestCase {
    func test_onEnd_withSampledSpan_forwardsSampledSpanToExporter() async throws {
        let exporter = OTelStreamingSpanExporter()
        let processor = OTelSimpleSpanProcessor(exporter: exporter)

        try await withThrowingTaskGroup { group in
            let serviceGroup = ServiceGroup(services: [processor], logger: ._otelDebug)
            group.addTask { try await serviceGroup.run() }

            let span = OTelFinishedSpan.stub(traceFlags: .sampled, operationName: "test")
            processor.onEnd(span)

            // wait for batch to be exported
            var exportedBatchess = exporter.batches.makeAsyncIterator()
            let batch = await exportedBatchess.next()

            XCTAssertEqual(try XCTUnwrap(batch).map(\.operationName), ["test"])

            await serviceGroup.triggerGracefulShutdown()
            try await group.waitForAll()
        }
    }

    func test_onEnd_withNonSampledSpan_doesNotForwardSpanToExporter() async throws {
        let exporter = OTelInMemorySpanExporter()
        let processor = OTelSimpleSpanProcessor(exporter: exporter)

        let span = OTelFinishedSpan.stub(traceFlags: [], operationName: "test")
        processor.onEnd(span)

        // wait for exporter to be invoked asynchronously
        try await Task.sleep(for: .milliseconds(100))

        let exportedBatches = await exporter.exportedBatches
        XCTAssertTrue(exportedBatches.isEmpty)
    }

    func test_forceFlush_forceFlushesExporter() async throws {
        let exporter = OTelInMemorySpanExporter()
        let processor = OTelSimpleSpanProcessor(exporter: exporter)

        try await processor.forceFlush()

        let numberOfForceFlushes = await exporter.numberOfForceFlushes
        XCTAssertEqual(numberOfForceFlushes, 1)
    }

    func test_shutdown_shutsDownExporter() async throws {
        let exporter = OTelInMemorySpanExporter()
        let processor = OTelSimpleSpanProcessor(exporter: exporter)
        let wrapper = ServiceWrapper(service: processor)

        try await withThrowingTaskGroup { group in
            let serviceGroup = ServiceGroup(services: [wrapper], logger: ._otelDebug)
            group.addTask { try await serviceGroup.run() }
            await wrapper.runCalled
            await serviceGroup.triggerGracefulShutdown()
            try await group.waitForAll()
        }

        let numberOfShutdowns = await exporter.numberOfShutdowns
        XCTAssertEqual(numberOfShutdowns, 1)
    }
}

extension OTelSimpleSpanProcessor {
    // Overload with logging disabled.
    init(exporter: Exporter) {
        self.init(exporter: exporter, logger: ._otelDisabled)
    }
}

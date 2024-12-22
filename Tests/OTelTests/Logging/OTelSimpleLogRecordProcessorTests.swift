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

@testable import Logging
@_spi(Logging) import OTel
import OTelTesting
import XCTest

final class OTelSimpleLogRecordProcessorTests: XCTestCase {
    private let resource = OTelResource(attributes: ["service.name": "log_simple_processor_tests"])

    func testSimpleLogProcessorEmitsIndividualEntries() async throws {
        let exporter = OTelInMemoryLogRecordExporter()
        let simpleProcessor = OTelSimpleLogRecordProcessor(exporter: exporter)

        await withThrowingTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask(operation: simpleProcessor.run)

            var iterator = exporter.didRecordBatch.makeAsyncIterator()
            let logHandler = OTelLogHandler(processor: simpleProcessor, logLevel: .debug, resource: resource)
            let logger = Logger(label: "Test", logHandler)

            for i in 1 ... 4 {
                logger.info("\(i)")

                let recorded = await iterator.next()
                XCTAssertEqual(recorded, 1)
                XCTAssertEqual(exporter.records.count, i)
            }

            taskGroup.cancelAll()
        }
    }
}

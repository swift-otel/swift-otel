//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2025 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Testing

@testable import OTel

@Suite struct OTelBackendTests {
    @Test func testAutomaticLogRecordProcessorSelectionForOTLPHTTPExporter() async throws {
        let processor = try WrappedLogRecordProcessor(
            configuration: .default,
            exporter: .http(OTLPHTTPLogRecordExporter(configuration: .default, logger: ._otelDisabled)),
            logger: ._otelDisabled
        )
        guard case .batch = processor else {
            Issue.record(
                "OTLP/HTTP exporter should be automatically paired with the batch processor, but paired with: \(processor)"
            )
            return
        }
    }

    @available(gRPCSwift, *)
    @Test func testAutomaticLogRecordProcessorSelectionForOTLPGRPCExporter() async throws {
        var config = OTel.Configuration.default
        config.logs.otlpExporter.protocol = .grpc
        let processor = try WrappedLogRecordProcessor(
            configuration: config,
            exporter: .grpc(OTLPGRPCLogRecordExporter(configuration: config.logs.otlpExporter, logger: ._otelDisabled)),
            logger: ._otelDisabled
        )
        guard case .batch = processor else {
            Issue.record(
                "OTLP/gRPC exporter should be automatically paired with the batch processor, but paired with: \(processor)"
            )
            return
        }
    }

    @Test func testAutomaticLogRecordProcessorSelectionForConsoleExporter() async throws {
        let processor = try WrappedLogRecordProcessor(
            configuration: .default,
            exporter: .console(OTelConsoleLogRecordExporter()),
            logger: ._otelDisabled
        )
        guard case .simple = processor else {
            Issue.record(
                "Console exporter should be automatically paired with the batch processor, but paired with: \(processor)"
            )
            return
        }
    }

    @Test func testAutomaticLogRecordProcessorSelectionForNoneExporter() async throws {
        let processor = try WrappedLogRecordProcessor(
            configuration: .default,
            exporter: .none,
            logger: ._otelDisabled
        )
        guard case .simple = processor else {
            Issue.record(
                "None exporter should be automatically paired with the simple processor, but paired with: \(processor)"
            )
            return
        }
    }
}

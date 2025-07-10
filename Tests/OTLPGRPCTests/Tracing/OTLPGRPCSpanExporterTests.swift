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
import NIO
@testable import OTelCore
import OTelTesting
@testable import OTLPGRPC
import Tracing
import XCTest

final class OTLPGRPCSpanExporterTests: XCTestCase {
    private var requestLogger: Logger!
    private var backgroundActivityLogger: Logger!

    override func setUp() async throws {
        LoggingSystem.bootstrapInternal(logLevel: .trace)
        requestLogger = Logger(label: "requestLogger")
        backgroundActivityLogger = Logger(label: "backgroundActivityLogger")
    }

    fileprivate func withExporter<Result>(
        configuration: OTel.Configuration.OTLPExporterConfiguration,
        operation: (OTLPGRPCSpanExporter) async throws -> Result
    ) async throws -> Result {
        try await withThrowingTaskGroup { group in
            let exporter = try OTLPGRPCSpanExporter(configuration: configuration)
            group.addTask { try await exporter.run() }
            let result = try await operation(exporter)
            await exporter.shutdown()
            try await group.waitForAll()
            return result
        }
    }

    func test_export_whenConnected_withInsecureConnection_sendsExportRequestToCollector() async throws {
        try await OTLPGRPCMockCollector.withInsecureServer { collector, endpoint in
            var configuration = OTel.Configuration.OTLPExporterConfiguration.default
            configuration.protocol = .grpc
            configuration.endpoint = endpoint
            try await withExporter(configuration: configuration) { exporter in
                let span = OTelFinishedSpan.stub()
                try await exporter.export([span])
            }

            XCTAssertEqual(collector.recordingTraceService.recordingService.requests.count, 1)
            let request = try XCTUnwrap(collector.recordingTraceService.recordingService.requests.first)

            XCTAssertEqual(
                request.metadata.first(where: { $0.key == "user-agent" })?.value,
                "OTel-OTLP-Exporter-Swift/\(OTelLibrary.version)"
            )
        }
    }

    func test_export_whenConnected_withSecureConnection_sendsExportRequestToCollector() async throws {
        try await OTLPGRPCMockCollector.withSecureServer { collector, endpoint, trustRootsPath in
            var configuration = OTel.Configuration.OTLPExporterConfiguration.default
            configuration.protocol = .grpc
            configuration.endpoint = endpoint
            configuration.certificateFilePath = trustRootsPath
            try await withExporter(configuration: configuration) { exporter in
                let span = OTelFinishedSpan.stub()
                try await exporter.export([span])
            }

            XCTAssertEqual(collector.recordingTraceService.recordingService.requests.count, 1)
            let request = try XCTUnwrap(collector.recordingTraceService.recordingService.requests.first)

            XCTAssertEqual(
                request.metadata.first(where: { $0.key == "user-agent" })?.value,
                "OTel-OTLP-Exporter-Swift/\(OTelLibrary.version)"
            )
        }
    }

    func test_export_withCustomHeaders_includesCustomHeadersInExportRequest() async throws {
        try await OTLPGRPCMockCollector.withInsecureServer { collector, endpoint in
            var configuration = OTel.Configuration.OTLPExporterConfiguration.default
            configuration.protocol = .grpc
            configuration.endpoint = endpoint
            configuration.headers = [
                ("key1", "42"),
                ("key2", "84"),
            ]

            let span = OTelFinishedSpan.stub(resource: OTelResource(attributes: ["service.name": "test"]))
            try await withExporter(configuration: configuration) { exporter in
                try await exporter.export([span])
            }

            XCTAssertEqual(collector.recordingTraceService.recordingService.requests.count, 1)
            let request = try XCTUnwrap(collector.recordingTraceService.recordingService.requests.first)

            XCTAssertEqual(request.message.resourceSpans.count, 1)
            let resourceSpans = try XCTUnwrap(request.message.resourceSpans.first)
            XCTAssertEqual(resourceSpans.resource, .with {
                $0.attributes = .init(["service.name": "test"])
            })
            XCTAssertEqual(resourceSpans.scopeSpans.count, 1)
            let scopeSpans = try XCTUnwrap(resourceSpans.scopeSpans.first)
            XCTAssertEqual(scopeSpans.scope, .with {
                $0.name = "swift-otel"
                $0.version = OTelLibrary.version
            })
            XCTAssertEqual(scopeSpans.spans, [.init(span)])

            XCTAssertEqual(request.metadata.first(where: { $0.key == "key1" })?.value, "42")
            XCTAssertEqual(request.metadata.first(where: { $0.key == "key2" })?.value, "84")
        }
    }

    func test_export_whenAlreadyShutdown_throwsAlreadyShutdownError() async throws {
        try await OTLPGRPCMockCollector.withInsecureServer { _, endpoint in
            do {
                var configuration = OTel.Configuration.OTLPExporterConfiguration.default
                configuration.protocol = .grpc
                configuration.endpoint = endpoint
                let exporter = try OTLPGRPCSpanExporter(configuration: configuration)
                await exporter.shutdown()

                let span = OTelFinishedSpan.stub()
                try await exporter.export([span])

                XCTFail("Expected exporter to throw error, successfully exported instead.")
            } catch OTLPGRPCExporterError.exporterAlreadyShutDown {}
        }
    }

    func test_forceFlush() async throws {
        // This exporter is a "push exporter" and so the OTel spec says that force flush should do nothing.
        try await OTLPGRPCMockCollector.withInsecureServer { _, endpoint in
            var configuration = OTel.Configuration.OTLPExporterConfiguration.default
            configuration.protocol = .grpc
            configuration.endpoint = endpoint
            let exporter = try OTLPGRPCSpanExporter(configuration: configuration)
            try await exporter.forceFlush()
        }
    }
}

extension OTLPGRPCSpanExporter {
    // Overload with logging disabled.
    convenience init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        try self.init(configuration: configuration, logger: ._otelDisabled)
    }
}

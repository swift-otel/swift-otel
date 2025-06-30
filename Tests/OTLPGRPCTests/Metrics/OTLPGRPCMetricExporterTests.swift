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
import OTLPCore
@testable import OTLPGRPC
import XCTest

final class OTLPGRPCMetricExporterTests: XCTestCase {
    private var requestLogger: Logger!
    private var backgroundActivityLogger: Logger!

    override func setUp() async throws {
        LoggingSystem.bootstrapInternal(logLevel: .trace)
        requestLogger = Logger(label: "requestLogger")
        backgroundActivityLogger = Logger(label: "backgroundActivityLogger")
    }

    fileprivate func withExporter<Result>(
        configuration: OTel.Configuration.OTLPExporterConfiguration,
        operation: (OTLPGRPCMetricExporter) async throws -> Result
    ) async throws -> Result {
        try await withThrowingTaskGroup { group in
            let exporter = try OTLPGRPCMetricExporter(configuration: configuration)
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
                let metrics = OTelResourceMetrics(scopeMetrics: [])
                try await exporter.export([metrics])
            }

            XCTAssertEqual(collector.recordingMetricsService.recordingService.requests.count, 1)
            let request = try XCTUnwrap(collector.recordingMetricsService.recordingService.requests.first)

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
                let metrics = OTelResourceMetrics(scopeMetrics: [])
                try await exporter.export([metrics])
            }

            XCTAssertEqual(collector.recordingMetricsService.recordingService.requests.count, 1)
            let request = try XCTUnwrap(collector.recordingMetricsService.recordingService.requests.first)

            XCTAssertEqual(
                request.metadata.first(where: { $0.key == "user-agent" })?.value,
                "OTel-OTLP-Exporter-Swift/\(OTelLibrary.version)"
            )
        }
    }

    func test_export_withCustomHeaders_includesCustomHeadersInExportRequest() async throws {
        let resourceMetricsToExport = OTelResourceMetrics(
            resource: OTelResource(attributes: ["service.name": "mock_service"]),
            scopeMetrics: [
                .init(
                    scope: .init(
                        name: "scope_name",
                        version: "scope_version",
                        attributes: [.init(key: "scope_attr_key", value: "scope_attr_val")],
                        droppedAttributeCount: 0
                    ),
                    metrics: [
                        .init(
                            name: "mock_metric",
                            description: "mock description",
                            unit: "ms",
                            data: .gauge(.init(points: [
                                .init(
                                    attributes: [.init(key: "point_attr_key", value: "point_attr_val")],
                                    timeNanosecondsSinceEpoch: 42,
                                    value: .double(84.6)
                                ),
                            ]))
                        ),
                    ]
                ),
            ]
        )

        try await OTLPGRPCMockCollector.withInsecureServer { collector, endpoint in
            var configuration = OTel.Configuration.OTLPExporterConfiguration.default
            configuration.protocol = .grpc
            configuration.endpoint = endpoint
            configuration.headers = [
                ("key1", "42"),
                ("key2", "84"),
            ]
            try await withExporter(configuration: configuration) { exporter in
                try await exporter.export([resourceMetricsToExport])
            }

            XCTAssertEqual(collector.recordingMetricsService.recordingService.requests.count, 1)
            let request = try XCTUnwrap(collector.recordingMetricsService.recordingService.requests.first)

            XCTAssertEqual(request.message.resourceMetrics.count, 1)
            let resourceMetrics = try XCTUnwrap(request.message.resourceMetrics.first)
            XCTAssertEqual(resourceMetrics.resource, .with {
                $0.attributes = .init(["service.name": "mock_service"])
            })
            XCTAssertEqual(resourceMetrics.scopeMetrics.count, 1)
            let scopeMetrics = try XCTUnwrap(resourceMetrics.scopeMetrics.first)
            XCTAssertEqual(scopeMetrics.scope, .with {
                $0.name = "scope_name"
                $0.version = "scope_version"
                $0.attributes = [
                    .with {
                        $0.key = "scope_attr_key"
                        $0.value = .init("scope_attr_val")
                    },
                ]
            })
            XCTAssertEqual(scopeMetrics.metrics, .init(resourceMetricsToExport.scopeMetrics.first!.metrics))

            XCTAssertEqual(request.metadata.first(where: { $0.key == "key1" })?.value, "42")
            XCTAssertEqual(request.metadata.first(where: { $0.key == "key2" })?.value, "84")
        }
    }

    func test_export_whenAlreadyShutdown_throwsAlreadyShutdownError() async throws {
        try await OTLPGRPCMockCollector.withInsecureServer { _, endpoint in
            let errorCaught = expectation(description: "Caught expected error")
            do {
                var configuration = OTel.Configuration.OTLPExporterConfiguration.default
                configuration.protocol = .grpc
                configuration.endpoint = endpoint
                let exporter = try OTLPGRPCMetricExporter(configuration: configuration)
                await exporter.shutdown()

                let metrics = OTelResourceMetrics(scopeMetrics: [])
                try await exporter.export([metrics])

                XCTFail("Expected exporter to throw error, successfully exported instead.")
            } catch OTLPGRPCExporterError.exporterAlreadyShutDown {
                errorCaught.fulfill()
            }
            await fulfillment(of: [errorCaught], timeout: 0.0)
        }
    }

    func test_forceFlush() async throws {
        // This exporter is a "push exporter" and so the OTel spec says that force flush should do nothing.
        try await OTLPGRPCMockCollector.withInsecureServer { _, endpoint in
            var configuration = OTel.Configuration.OTLPExporterConfiguration.default
            configuration.protocol = .grpc
            configuration.endpoint = endpoint
            let exporter = try OTLPGRPCMetricExporter(configuration: configuration)
            try await exporter.forceFlush()
        }
    }
}

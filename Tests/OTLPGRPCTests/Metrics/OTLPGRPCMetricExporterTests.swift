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
@testable import OTel
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

    func test_export_whenConnected_withInsecureConnection_sendsExportRequestToCollector() async throws {
        let collector = OTLPGRPCMockCollector()

        try await collector.withInsecureServer { endpoint in
            let configuration = try OTLPGRPCMetricExporterConfiguration(environment: [:], endpoint: endpoint)
            let exporter = OTLPGRPCMetricExporter(
                configuration: configuration,
                requestLogger: requestLogger,
                backgroundActivityLogger: backgroundActivityLogger
            )

            let metrics = OTelResourceMetrics(scopeMetrics: [])
            try await exporter.export([metrics])

            await exporter.shutdown()
        }

        XCTAssertEqual(collector.metricsProvider.requests.count, 1)
        let request = try XCTUnwrap(collector.metricsProvider.requests.first)

        XCTAssertEqual(
            request.headers.first(name: "user-agent"),
            "OTel-OTLP-Exporter-Swift/\(OTelLibrary.version)"
        )
    }

    func test_export_whenConnected_withSecureConnection_sendsExportRequestToCollector() async throws {
        let collector = OTLPGRPCMockCollector()

        try await collector.withSecureServer { endpoint, trustRoots in
            let configuration = try OTLPGRPCMetricExporterConfiguration(environment: [:], endpoint: endpoint)
            let exporter = OTLPGRPCMetricExporter(
                configuration: configuration,
                group: MultiThreadedEventLoopGroup.singleton,
                requestLogger: requestLogger,
                backgroundActivityLogger: backgroundActivityLogger,
                trustRoots: trustRoots
            )

            let metrics = OTelResourceMetrics(scopeMetrics: [])
            try await exporter.export([metrics])

            await exporter.shutdown()
        }

        XCTAssertEqual(collector.metricsProvider.requests.count, 1)
        let request = try XCTUnwrap(collector.metricsProvider.requests.first)

        XCTAssertEqual(
            request.headers.first(name: "user-agent"),
            "OTel-OTLP-Exporter-Swift/\(OTelLibrary.version)"
        )
    }

    func test_export_withCustomHeaders_includesCustomHeadersInExportRequest() async throws {
        let collector = OTLPGRPCMockCollector()
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

        try await collector.withInsecureServer { endpoint in
            let configuration = try OTLPGRPCMetricExporterConfiguration(
                environment: [:],
                endpoint: endpoint,
                headers: [
                    "key1": "42",
                    "key2": "84",
                ]
            )
            let exporter = OTLPGRPCMetricExporter(
                configuration: configuration,
                requestLogger: requestLogger,
                backgroundActivityLogger: backgroundActivityLogger
            )

            try await exporter.export([resourceMetricsToExport])

            await exporter.shutdown()
        }

        XCTAssertEqual(collector.metricsProvider.requests.count, 1)
        let request = try XCTUnwrap(collector.metricsProvider.requests.first)

        XCTAssertEqual(request.exportRequest.resourceMetrics.count, 1)
        let resourceMetrics = try XCTUnwrap(request.exportRequest.resourceMetrics.first)
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

        XCTAssertEqual(request.headers.first(name: "key1"), "42")
        XCTAssertEqual(request.headers.first(name: "key2"), "84")
    }

    func test_export_whenAlreadyShutdown_throwsAlreadyShutdownError() async throws {
        let collector = OTLPGRPCMockCollector()
        let errorCaught = expectation(description: "Caught expected error")
        do {
            try await collector.withInsecureServer { endpoint in
                let configuration = try OTLPGRPCMetricExporterConfiguration(environment: [:], endpoint: endpoint)
                let exporter = OTLPGRPCMetricExporter(
                    configuration: configuration,
                    requestLogger: requestLogger,
                    backgroundActivityLogger: backgroundActivityLogger
                )
                await exporter.shutdown()

                let metrics = OTelResourceMetrics(scopeMetrics: [])
                try await exporter.export([metrics])

                XCTFail("Expected exporter to throw error, successfully exported instead.")
            }
        } catch is OTelMetricExporterAlreadyShutDownError {
            errorCaught.fulfill()
        }
        await fulfillment(of: [errorCaught], timeout: 0.0)
    }

    func test_forceFlush() async throws {
        // This exporter is a "push exporter" and so the OTel spec says that force flush should do nothing.
        let configuration = try OTLPGRPCMetricExporterConfiguration(environment: [:])
        let exporter = OTLPGRPCMetricExporter(configuration: configuration)
        try await exporter.forceFlush()
    }
}

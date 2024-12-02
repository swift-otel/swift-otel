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

import GRPC
@testable import Logging
import NIO
@testable import OTel
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

    func test_export_whenConnected_withInsecureConnection_sendsExportRequestToCollector() async throws {
        let collector = OTLPGRPCMockCollector()

        try await collector.withInsecureServer { endpoint in
            let configuration = try OTLPGRPCSpanExporterConfiguration(environment: [:], endpoint: endpoint)
            let exporter = OTLPGRPCSpanExporter(
                configuration: configuration,
                requestLogger: requestLogger,
                backgroundActivityLogger: backgroundActivityLogger
            )

            let span = OTelFinishedSpan.stub()
            try await exporter.export([span])

            await exporter.shutdown()
        }

        XCTAssertEqual(collector.traceProvider.requests.count, 1)
        let request = try XCTUnwrap(collector.traceProvider.requests.first)

        XCTAssertEqual(
            request.headers.first(name: "user-agent"),
            "OTel-OTLP-Exporter-Swift/\(OTelLibrary.version)"
        )
    }

    func test_export_whenConnected_withSecureConnection_sendsExportRequestToCollector() async throws {
        let collector = OTLPGRPCMockCollector()

        try await collector.withSecureServer { endpoint, trustRoots in
            let configuration = try OTLPGRPCSpanExporterConfiguration(environment: [:], endpoint: endpoint)
            let exporter = OTLPGRPCSpanExporter(
                configuration: configuration,
                group: MultiThreadedEventLoopGroup.singleton,
                requestLogger: requestLogger,
                backgroundActivityLogger: backgroundActivityLogger,
                trustRoots: trustRoots
            )

            let span = OTelFinishedSpan.stub()
            try await exporter.export([span])

            await exporter.shutdown()
        }

        XCTAssertEqual(collector.traceProvider.requests.count, 1)
        let request = try XCTUnwrap(collector.traceProvider.requests.first)

        XCTAssertEqual(
            request.headers.first(name: "user-agent"),
            "OTel-OTLP-Exporter-Swift/\(OTelLibrary.version)"
        )
    }

    func test_export_withCustomHeaders_includesCustomHeadersInExportRequest() async throws {
        let collector = OTLPGRPCMockCollector()
        let span = OTelFinishedSpan.stub(resource: OTelResource(attributes: ["service.name": "test"]))

        try await collector.withInsecureServer { endpoint in
            let configuration = try OTLPGRPCSpanExporterConfiguration(
                environment: [:],
                endpoint: endpoint,
                headers: [
                    "key1": "42",
                    "key2": "84",
                ]
            )
            let exporter = OTLPGRPCSpanExporter(
                configuration: configuration,
                requestLogger: requestLogger,
                backgroundActivityLogger: backgroundActivityLogger
            )

            try await exporter.export([span])

            await exporter.shutdown()
        }

        XCTAssertEqual(collector.traceProvider.requests.count, 1)
        let request = try XCTUnwrap(collector.traceProvider.requests.first)

        XCTAssertEqual(request.exportRequest.resourceSpans.count, 1)
        let resourceSpans = try XCTUnwrap(request.exportRequest.resourceSpans.first)
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

        XCTAssertEqual(request.headers.first(name: "key1"), "42")
        XCTAssertEqual(request.headers.first(name: "key2"), "84")
    }

    func test_export_whenAlreadyShutdown_throwsAlreadyShutdownError() async throws {
        let collector = OTLPGRPCMockCollector()

        do {
            try await collector.withInsecureServer { endpoint in
                let configuration = try OTLPGRPCSpanExporterConfiguration(environment: [:], endpoint: endpoint)
                let exporter = OTLPGRPCSpanExporter(
                    configuration: configuration,
                    requestLogger: requestLogger,
                    backgroundActivityLogger: backgroundActivityLogger
                )
                await exporter.shutdown()

                let span = OTelFinishedSpan.stub()
                try await exporter.export([span])

                XCTFail("Expected exporter to throw error, successfully exported instead.")
            }
        } catch is OTelSpanExporterAlreadyShutDownError {}
    }

    func test_forceFlush() async throws {
        // This exporter is a "push exporter" and so the OTel spec says that force flush should do nothing.
        let configuration = try OTLPGRPCSpanExporterConfiguration(environment: [:])
        let exporter = OTLPGRPCSpanExporter(configuration: configuration)
        try await exporter.forceFlush()
    }
}

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

import Foundation
import NIO
import OTLPGRPC
import OTel
import ServiceLifecycle
import W3CTraceContext
import XCTest

@testable import Instrumentation
@testable import Logging

final class OTLPGRPCIntegrationTests: XCTestCase, @unchecked Sendable {
    func test_example() async throws {
        LoggingSystem.bootstrapInternal { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .trace
            return handler
        }
        let logger = Logger(label: "test")
        let group = MultiThreadedEventLoopGroup.singleton
        let exporter = try OTLPGRPCSpanExporter(
            configuration: OTLPGRPCSpanExporterConfiguration(environment: [:]),
            group: group,
            requestLogger: logger,
            backgroundActivityLogger: logger
        )
        let processor = OTelBatchSpanProcessor(
            exporter: exporter,
            configuration: .init(
                environment: [:],
                scheduleDelay: .zero
            )
        )
        let tracer = OTelTracer(
            idGenerator: OTelRandomIDGenerator(),
            sampler: OTelConstantSampler(isOn: true),
            propagator: OTelW3CPropagator(),
            processor: processor,
            environment: [:],
            resource: OTelResource(attributes: ["service.name": "IntegrationTests"])
        )

        InstrumentationSystem.bootstrapInternal(tracer)

        let serviceGroup = ServiceGroup(
            configuration: .init(
                services: [
                    .init(service: tracer),
                    .init(service: TestService(), successTerminationBehavior: .gracefullyShutdownGroup),
                ],
                logger: logger
            )
        )
        try await serviceGroup.run()
    }
}

struct TestService: Service {
    func run() async throws {
        let otelCollectorOutputPath = try XCTUnwrap(ProcessInfo.processInfo.environment["OTEL_COLLECTOR_OUTPUT"])
        let outputFileURL = URL(fileURLWithPath: otelCollectorOutputPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputFileURL.path), outputFileURL.path)

        let span = InstrumentationSystem.tracer.startSpan("test")
        span.attributes["foo"] = "bar"
        span.setStatus(.init(code: .ok))
        span.end()

        // wait for export
        try await Task.sleep(for: .seconds(2))

        let jsonDecoder = JSONDecoder()
        let outputFileContents = try String(contentsOf: outputFileURL, encoding: .utf8).trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let lines = outputFileContents.components(separatedBy: .newlines)
        let exportLine = try XCTUnwrap(lines.last)
        let decodedExportLine = try jsonDecoder.decode(ExportLine.self, from: Data(exportLine.utf8))
        let resourceSpans = try XCTUnwrap(decodedExportLine.resourceSpans.first)
        let scopeSpans = try XCTUnwrap(resourceSpans.scopeSpans.first)
        let exportedSpan = try XCTUnwrap(scopeSpans.spans.first)

        XCTAssertEqual(exportedSpan.spanID, span.context.spanContext?.spanID.description)
        XCTAssertEqual(exportedSpan.traceID, span.context.spanContext?.traceID.description)
        XCTAssertEqual(exportedSpan.name, "test")
        XCTAssertEqual(exportedSpan.attributes, [.init(key: "foo", value: .init(stringValue: "bar"))])
    }
}

struct ExportLine: Decodable {
    let resourceSpans: [ResourceSpan]

    struct ResourceSpan: Decodable {
        let scopeSpans: [ScopeSpans]

        struct ScopeSpans: Decodable {
            let spans: [Span]

            struct Span: Decodable {
                let traceID: String
                let spanID: String
                let name: String
                let attributes: [Attribute]

                private enum CodingKeys: String, CodingKey {
                    case traceID = "traceId"
                    case spanID = "spanId"
                    case name
                    case attributes
                }

                struct Attribute: Decodable, Equatable {
                    let key: String
                    let value: Value

                    struct Value: Decodable, Equatable {
                        let stringValue: String
                    }
                }
            }
        }
    }
}

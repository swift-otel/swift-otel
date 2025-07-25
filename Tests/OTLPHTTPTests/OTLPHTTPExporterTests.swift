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

import struct Foundation.Data
import Metrics
import NIOTestUtils
@testable import OTel
@testable import OTelCore
@testable import OTelTesting
import OTLPCore
@testable import OTLPHTTP
import ServiceLifecycle
import Testing
import Tracing

@Suite(.serialized) struct OTLPHTTPExporterTests {
    @Test func testOTLPHTTPSpanExporterProtobuf() async throws {
        try await withThrowingTaskGroup { group in
            let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
            defer { #expect(throws: Never.self) { try testServer.stop() } }

            // Client
            group.addTask {
                var config = OTel.Configuration.OTLPExporterConfiguration.default
                config.endpoint = "http://127.0.0.1:\(testServer.serverPort)/some/path"
                config.protocol = .httpProtobuf
                let exporter = try OTLPHTTPSpanExporter(configuration: config)
                let span = OTelFinishedSpan.stub()
                await #expect(throws: Never.self) { try await exporter.export([span]) }
            }

            try testServer.receiveHeadAndVerify { head in
                #expect(head.method == .POST)
                #expect(head.uri == "/some/path")
                #expect(head.headers["Content-Type"] == ["application/x-protobuf"])
            }
            try testServer.receiveBodyAndVerify { body in
                let message = try Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest(serializedBytes: Data(buffer: body))
                #expect(message.resourceSpans.count == 1)
            }
            try testServer.receiveEndAndVerify { trailers in
                #expect(trailers == nil)
            }

            try testServer.writeOutbound(.head(.init(version: .http1_1, status: .ok, headers: ["Content-Type": "application/x-protobuf"])))
            let response = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse()
            try testServer.writeOutbound(.body(.byteBuffer(.init(data: response.serializedData()))))
            try testServer.writeOutbound(.end(nil))

            try await group.waitForAll()
        }
    }

    @Test func testOTLPHTTPSpanExporterJSON() async throws {
        try await withThrowingTaskGroup { group in
            let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
            defer { #expect(throws: Never.self) { try testServer.stop() } }

            // Client
            group.addTask {
                var config = OTel.Configuration.OTLPExporterConfiguration.default
                config.protocol = .httpJSON
                config.endpoint = "http://127.0.0.1:\(testServer.serverPort)/some/path"
                let exporter = try OTLPHTTPSpanExporter(configuration: config)
                let span = OTelFinishedSpan.stub()
                await #expect(throws: Never.self) { try await exporter.export([span]) }
            }

            try testServer.receiveHeadAndVerify { head in
                #expect(head.method == .POST)
                #expect(head.uri == "/some/path")
                #expect(head.headers["Content-Type"] == ["application/json"])
            }
            try testServer.receiveBodyAndVerify { body in
                let message = try Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest(jsonUTF8Bytes: Data(buffer: body))
                #expect(message.resourceSpans.count == 1)
            }
            try testServer.receiveEndAndVerify { trailers in
                #expect(trailers == nil)
            }

            try testServer.writeOutbound(.head(.init(version: .http1_1, status: .ok, headers: ["Content-Type": "application/json"])))
            let response = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse()
            try testServer.writeOutbound(.body(.byteBuffer(.init(data: response.jsonUTF8Data()))))
            try testServer.writeOutbound(.end(nil))

            try await group.waitForAll()
        }
    }

    @Test func testOTLPHTTPMetricExporterProtobuf() async throws {
        try await withThrowingTaskGroup { group in
            let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
            defer { #expect(throws: Never.self) { try testServer.stop() } }

            // Client
            group.addTask {
                var config = OTel.Configuration.OTLPExporterConfiguration.default
                config.endpoint = "http://127.0.0.1:\(testServer.serverPort)/some/path"
                config.protocol = .httpProtobuf
                let exporter = try OTLPHTTPMetricExporter(configuration: config)
                let batch = [OTelResourceMetrics(scopeMetrics: [.stub(metrics: [.stub()])])]
                await #expect(throws: Never.self) { try await exporter.export(batch) }
            }

            try testServer.receiveHeadAndVerify { head in
                #expect(head.method == .POST)
                #expect(head.uri == "/some/path")
                #expect(head.headers["Content-Type"] == ["application/x-protobuf"])
            }
            try testServer.receiveBodyAndVerify { body in
                let message = try Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest(serializedBytes: Data(buffer: body))
                #expect(message.resourceMetrics.count == 1)
            }
            try testServer.receiveEndAndVerify { trailers in
                #expect(trailers == nil)
            }

            try testServer.writeOutbound(.head(.init(version: .http1_1, status: .ok, headers: ["Content-Type": "application/x-protobuf"])))
            let response = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse()
            try testServer.writeOutbound(.body(.byteBuffer(.init(data: response.serializedData()))))
            try testServer.writeOutbound(.end(nil))

            try await group.waitForAll()
        }
    }

    @Test func testOTLPHTTPMetricExporterJSON() async throws {
        try await withThrowingTaskGroup { group in
            let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
            defer { #expect(throws: Never.self) { try testServer.stop() } }

            // Client
            group.addTask {
                var config = OTel.Configuration.OTLPExporterConfiguration.default
                config.protocol = .httpJSON
                config.endpoint = "http://127.0.0.1:\(testServer.serverPort)/some/path"
                let exporter = try OTLPHTTPMetricExporter(configuration: config)
                let batch = [OTelResourceMetrics(scopeMetrics: [.stub(metrics: [.stub()])])]
                await #expect(throws: Never.self) { try await exporter.export(batch) }
            }

            try testServer.receiveHeadAndVerify { head in
                #expect(head.method == .POST)
                #expect(head.uri == "/some/path")
                #expect(head.headers["Content-Type"] == ["application/json"])
            }
            try testServer.receiveBodyAndVerify { body in
                let message = try Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest(jsonUTF8Bytes: Data(buffer: body))
                #expect(message.resourceMetrics.count == 1)
            }
            try testServer.receiveEndAndVerify { trailers in
                #expect(trailers == nil)
            }

            try testServer.writeOutbound(.head(.init(version: .http1_1, status: .ok, headers: ["Content-Type": "application/json"])))
            let response = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse()
            try testServer.writeOutbound(.body(.byteBuffer(.init(data: response.jsonUTF8Data()))))
            try testServer.writeOutbound(.end(nil))

            try await group.waitForAll()
        }
    }

    @Test func testOTLPHTTPLogRecordExporterProtobuf() async throws {
        try await withThrowingTaskGroup { group in
            let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
            defer { #expect(throws: Never.self) { try testServer.stop() } }

            // Client
            group.addTask {
                var config = OTel.Configuration.OTLPExporterConfiguration.default
                config.endpoint = "http://127.0.0.1:\(testServer.serverPort)/some/path"
                config.protocol = .httpProtobuf
                let exporter = try OTLPHTTPLogRecordExporter(configuration: config)
                try await exporter.export([OTelLogRecord(body: "Hello", level: .trace, metadata: ["foo": "bar"], timeNanosecondsSinceEpoch: 1234, resource: OTelResource(), spanContext: nil)])
                await exporter.shutdown()
            }

            try testServer.receiveHeadAndVerify { head in
                #expect(head.method == .POST)
                #expect(head.uri == "/some/path")
                #expect(head.headers["Content-Type"] == ["application/x-protobuf"])
            }
            try testServer.receiveBodyAndVerify { body in
                let message = try Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest(serializedBytes: Data(buffer: body))
                #expect(message.resourceLogs.count == 1)
                #expect(message.resourceLogs.first?.scopeLogs.count == 1)
                #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.count == 1)
                #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.body == .init("Hello"))
                #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.attributes.first { $0.key == "foo" }?.value == .init("bar"))
                #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.timeUnixNano == 1234)
            }
            try testServer.receiveEndAndVerify { trailers in
                #expect(trailers == nil)
            }

            try testServer.writeOutbound(.head(.init(version: .http1_1, status: .ok, headers: ["Content-Type": "application/x-protobuf"])))
            let response = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse()
            try testServer.writeOutbound(.body(.byteBuffer(.init(data: response.serializedData()))))
            try testServer.writeOutbound(.end(nil))

            try await group.waitForAll()
        }
    }

    @Test func testOTLPHTTPLogRecordExporterJSON() async throws {
        try await withThrowingTaskGroup { group in
            let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
            defer { #expect(throws: Never.self) { try testServer.stop() } }

            // Client
            group.addTask {
                var config = OTel.Configuration.OTLPExporterConfiguration.default
                config.endpoint = "http://127.0.0.1:\(testServer.serverPort)/some/path"
                config.protocol = .httpJSON
                let exporter = try OTLPHTTPLogRecordExporter(configuration: config)
                try await exporter.export([OTelLogRecord(body: "Hello", level: .trace, metadata: ["foo": "bar"], timeNanosecondsSinceEpoch: 1234, resource: OTelResource(), spanContext: nil)])
                await exporter.shutdown()
            }

            try testServer.receiveHeadAndVerify { head in
                #expect(head.method == .POST)
                #expect(head.uri == "/some/path")
                #expect(head.headers["Content-Type"] == ["application/json"])
            }
            try testServer.receiveBodyAndVerify { body in
                let message = try Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest(jsonUTF8Bytes: Data(buffer: body))
                #expect(message.resourceLogs.count == 1)
                #expect(message.resourceLogs.first?.scopeLogs.count == 1)
                #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.count == 1)
                #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.body == .init("Hello"))
                #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.attributes.first { $0.key == "foo" }?.value == .init("bar"))
                #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.timeUnixNano == 1234)
            }
            try testServer.receiveEndAndVerify { trailers in
                #expect(trailers == nil)
            }

            try testServer.writeOutbound(.head(.init(version: .http1_1, status: .ok, headers: ["Content-Type": "application/json"])))
            let response = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse()
            try testServer.writeOutbound(.body(.byteBuffer(.init(data: response.jsonUTF8Data()))))
            try testServer.writeOutbound(.end(nil))

            try await group.waitForAll()
        }
    }
}

extension OTLPHTTPLogRecordExporter {
    // Overload with logging disabled.
    convenience init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        try self.init(configuration: configuration, logger: ._otelDisabled)
    }
}

extension OTLPHTTPMetricExporter {
    // Overload with logging disabled.
    convenience init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        try self.init(configuration: configuration, logger: ._otelDisabled)
    }
}

extension OTLPHTTPSpanExporter {
    // Overload with logging disabled.
    convenience init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        try self.init(configuration: configuration, logger: ._otelDisabled)
    }
}

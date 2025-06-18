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
import OTel
import OTLPCore
import ServiceLifecycle
import Testing
import Tracing

@Suite(.serialized) struct EndToEndTests {
    @Test func testTracesProtobufExportUsingBootstrap() async throws {
        /// Note: It's easier to debug this test by commenting out the surrounding `#expect(procesExitsWith:_:)`.
        await #expect(processExitsWith: .success, "Running in a separate process because test uses bootstrap") {
            try await withThrowingTaskGroup { group in
                let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
                defer { #expect(throws: Never.self) { try testServer.stop() } }

                // Client
                group.addTask {
                    var config = OTel.Configuration.default
                    config.logs.enabled = false
                    config.metrics.enabled = false
                    config.traces.otlpExporter.endpoint = "http://127.0.0.1:\(testServer.serverPort)/some/path"
                    config.traces.otlpExporter.protocol = .httpProtobuf
                    let observability = try OTel.bootstrap(configuration: config)
                    let serviceGroup = ServiceGroup(services: [observability], logger: .init(label: "service group"))

                    try await withThrowingTaskGroup { group in
                        group.addTask {
                            try await serviceGroup.run()
                        }
                        group.addTask {
                            withSpan("mysterious and important work") { _ in
                                withSpan("macrodata refinement") { _ in
                                    withSpan("cold harbor") { _ in }
                                    withSpan("billings") { _ in }
                                    withSpan("homestead") { _ in }
                                }
                            }
                            await serviceGroup.triggerGracefulShutdown()
                        }
                        try await group.waitForAll()
                    }
                }

                try testServer.receiveHeadAndVerify { head in
                    #expect(head.method == .POST)
                    #expect(head.uri == "/some/path")
                    #expect(head.headers["Content-Type"] == ["application/x-protobuf"])
                }
                try testServer.receiveBodyAndVerify { body in
                    let message = try Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest(serializedBytes: Data(buffer: body))
                    #expect(message.resourceSpans.count == 1)
                    #expect(message.resourceSpans.first?.scopeSpans.count == 1)
                    #expect(message.resourceSpans.first?.scopeSpans.first?.spans.count == 5)
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
    }

    @Test func testTracesJSONExportUsingBootstrap() async throws {
        /// Note: It's easier to debug this test by commenting out the surrounding `#expect(procesExitsWith:_:)`.
        await #expect(processExitsWith: .success, "Running in a separate process because test uses bootstrap") {
            try await withThrowingTaskGroup { group in
                let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
                defer { #expect(throws: Never.self) { try testServer.stop() } }

                // Client
                group.addTask {
                    var config = OTel.Configuration.default
                    config.logs.enabled = false
                    config.metrics.enabled = false
                    config.traces.otlpExporter.endpoint = "http://127.0.0.1:\(testServer.serverPort)/some/path"
                    config.traces.otlpExporter.protocol = .httpJSON
                    let observability = try OTel.bootstrap(configuration: config)
                    let serviceGroup = ServiceGroup(services: [observability], logger: .init(label: "service group"))

                    try await withThrowingTaskGroup { group in
                        group.addTask {
                            try await serviceGroup.run()
                        }
                        group.addTask {
                            withSpan("mysterious and important work") { _ in
                                withSpan("macrodata refinement") { _ in
                                    withSpan("cold harbor") { _ in }
                                    withSpan("billings") { _ in }
                                    withSpan("homestead") { _ in }
                                }
                            }
                            await serviceGroup.triggerGracefulShutdown()
                        }
                        try await group.waitForAll()
                    }
                }

                try testServer.receiveHeadAndVerify { head in
                    #expect(head.method == .POST)
                    #expect(head.uri == "/some/path")
                    #expect(head.headers["Content-Type"] == ["application/json"])
                }
                try testServer.receiveBodyAndVerify { body in
                    let message = try Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest(jsonUTF8Bytes: Data(buffer: body))
                    #expect(message.resourceSpans.count == 1)
                    #expect(message.resourceSpans.first?.scopeSpans.count == 1)
                    #expect(message.resourceSpans.first?.scopeSpans.first?.spans.count == 5)
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
    }

    @Test func testMetricsProtobufExportUsingBootstrap() async throws {
        /// Note: It's easier to debug this test by commenting out the surrounding `#expect(procesExitsWith:_:)`.
        await #expect(processExitsWith: .success, "Running in a separate process because test uses bootstrap") {
            try await withThrowingTaskGroup { group in
                let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
                defer { #expect(throws: Never.self) { try testServer.stop() } }

                // Client
                group.addTask {
                    var config = OTel.Configuration.default
                    config.logs.enabled = false
                    config.traces.enabled = false
                    config.metrics.otlpExporter.endpoint = "http://127.0.0.1:\(testServer.serverPort)/some/path"
                    config.metrics.otlpExporter.protocol = .httpProtobuf
                    let observability = try OTel.bootstrap(configuration: config)
                    let serviceGroup = ServiceGroup(services: [observability], logger: .init(label: "service group"))

                    try await withThrowingTaskGroup { group in
                        group.addTask {
                            try await serviceGroup.run()
                        }
                        group.addTask {
                            Gauge(label: "break_room.coffee_temperature").record(85)
                            Counter(label: "macro_data_refinement.files.processed").increment(by: 12)
                            Counter(label: "optics_design.revisions.count").increment(by: 99)
                            await serviceGroup.triggerGracefulShutdown()
                        }
                        try await group.waitForAll()
                    }
                }

                try testServer.receiveHeadAndVerify { head in
                    #expect(head.method == .POST)
                    #expect(head.uri == "/some/path")
                    #expect(head.headers["Content-Type"] == ["application/x-protobuf"])
                }
                try testServer.receiveBodyAndVerify { body in
                    let message = try Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest(serializedBytes: Data(buffer: body))
                    #expect(message.resourceMetrics.count == 1)
                    #expect(message.resourceMetrics.first?.scopeMetrics.count == 1)
                    #expect(message.resourceMetrics.first?.scopeMetrics.first?.metrics.count == 3)
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
    }

    @Test func testMetricsJSONExportUsingBootstrap() async throws {
        /// Note: It's easier to debug this test by commenting out the surrounding `#expect(procesExitsWith:_:)`.
        await #expect(processExitsWith: .success, "Running in a separate process because test uses bootstrap") {
            try await withThrowingTaskGroup { group in
                let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
                defer { #expect(throws: Never.self) { try testServer.stop() } }

                // Client
                group.addTask {
                    var config = OTel.Configuration.default
                    config.logs.enabled = false
                    config.traces.enabled = false
                    config.metrics.otlpExporter.endpoint = "http://127.0.0.1:\(testServer.serverPort)/some/path"
                    config.metrics.otlpExporter.protocol = .httpJSON
                    let observability = try OTel.bootstrap(configuration: config)
                    let serviceGroup = ServiceGroup(services: [observability], logger: .init(label: "service group"))

                    try await withThrowingTaskGroup { group in
                        group.addTask {
                            try await serviceGroup.run()
                        }
                        group.addTask {
                            Gauge(label: "break_room.coffee_temperature").record(85)
                            Counter(label: "macro_data_refinement.files.processed").increment(by: 12)
                            Counter(label: "optics_design.revisions.count").increment(by: 99)
                            await serviceGroup.triggerGracefulShutdown()
                        }
                        try await group.waitForAll()
                    }
                }

                try testServer.receiveHeadAndVerify { head in
                    #expect(head.method == .POST)
                    #expect(head.uri == "/some/path")
                    #expect(head.headers["Content-Type"] == ["application/json"])
                }
                try testServer.receiveBodyAndVerify { body in
                    let message = try Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest(jsonUTF8Data: Data(buffer: body))
                    #expect(message.resourceMetrics.count == 1)
                    #expect(message.resourceMetrics.first?.scopeMetrics.count == 1)
                    #expect(message.resourceMetrics.first?.scopeMetrics.first?.metrics.count == 3)
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
    }
}

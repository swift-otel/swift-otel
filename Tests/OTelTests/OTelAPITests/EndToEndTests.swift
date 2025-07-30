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

#if compiler(>=6.2) // Swift Testing exit tests only added in 6.2
import struct Foundation.Data
import Logging
import Metrics
import NIOTestUtils
import OTel // NOTE: Not @testable import because this test only uses public API.
import ServiceLifecycle
import Testing
import Tracing

@Suite(.serialized) struct EndToEndTests {
    init() {
        Testing.Test.workaround_SwiftTesting_1200()
    }

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
                    config.serviceName = "innie"
                    config.resourceAttributes = ["deployment.environment": "prod"]
                    let observability = try OTel.bootstrap(configuration: config)
                    let canary = Canary()
                    let serviceGroup = ServiceGroup(services: [observability, canary], logger: ._otelDebug)

                    try await withThrowingTaskGroup { group in
                        group.addTask {
                            try await serviceGroup.run()
                        }
                        await canary.running
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
                    #expect(message.resourceSpans.first?.resource.attributes.count == 2)
                    #expect(message.resourceSpans.first?.resource.attributes.first { $0.key == "service.name" }?.value.stringValue == "innie")
                    #expect(message.resourceSpans.first?.resource.attributes.first { $0.key == "deployment.environment" }?.value.stringValue == "prod")
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
                    config.serviceName = "innie"
                    config.resourceAttributes = ["deployment.environment": "prod"]
                    config.diagnosticLogLevel = .debug
                    let observability = try OTel.bootstrap(configuration: config)
                    let canary = Canary()
                    let serviceGroup = ServiceGroup(services: [observability, canary], logger: ._otelDebug)

                    try await withThrowingTaskGroup { group in
                        group.addTask {
                            try await serviceGroup.run()
                        }
                        await canary.running
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
                    #expect(message.resourceSpans.first?.resource.attributes.count == 2)
                    #expect(message.resourceSpans.first?.resource.attributes.first { $0.key == "service.name" }?.value.stringValue == "innie")
                    #expect(message.resourceSpans.first?.resource.attributes.first { $0.key == "deployment.environment" }?.value.stringValue == "prod")
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

    @available(gRPCSwift, *)
    @Test func testTracesGRPCExportUsingBootstrap() async throws {
        /// Note: It's easier to debug this test by commenting out the surrounding `#expect(procesExitsWith:_:)`.
        await #expect(processExitsWith: .success, "Running in a separate process because test uses bootstrap") {
            try await OTLPGRPCMockCollector.withInsecureServer { collector, endpoint in
                try await withThrowingTaskGroup { group in
                    var config = OTel.Configuration.default
                    config.logs.enabled = false
                    config.metrics.enabled = false
                    config.traces.otlpExporter.endpoint = endpoint
                    config.traces.otlpExporter.protocol = .grpc
                    config.serviceName = "innie"
                    config.resourceAttributes = ["deployment.environment": "prod"]
                    config.diagnosticLogLevel = .debug
                    let observability = try OTel.bootstrap(configuration: config)
                    let canary = Canary()
                    let serviceGroup = ServiceGroup(services: [observability, canary], logger: ._otelDebug)
                    group.addTask {
                        try await serviceGroup.run()
                    }
                    await canary.running
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
                #expect(collector.recordingTraceService.recordingService.requests.count == 1)
                let message = try #require(collector.recordingTraceService.recordingService.requests.first?.message)
                #expect(message.resourceSpans.count == 1)
                #expect(message.resourceSpans.first?.scopeSpans.count == 1)
                #expect(message.resourceSpans.first?.scopeSpans.first?.spans.count == 5)
                #expect(message.resourceSpans.first?.resource.attributes.count == 2)
                #expect(message.resourceSpans.first?.resource.attributes.first { $0.key == "service.name" }?.value.stringValue == "innie")
                #expect(message.resourceSpans.first?.resource.attributes.first { $0.key == "deployment.environment" }?.value.stringValue == "prod")
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
                    config.serviceName = "innie"
                    config.resourceAttributes = ["deployment.environment": "prod"]
                    let observability = try OTel.bootstrap(configuration: config)
                    let canary = Canary()
                    let serviceGroup = ServiceGroup(services: [observability, canary], logger: ._otelDebug)

                    try await withThrowingTaskGroup { group in
                        group.addTask {
                            try await serviceGroup.run()
                        }
                        await canary.running
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
                    #expect(message.resourceMetrics.first?.resource.attributes.count == 2)
                    #expect(message.resourceMetrics.first?.resource.attributes.first { $0.key == "service.name" }?.value.stringValue == "innie")
                    #expect(message.resourceMetrics.first?.resource.attributes.first { $0.key == "deployment.environment" }?.value.stringValue == "prod")
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
                    config.serviceName = "innie"
                    config.resourceAttributes = ["deployment.environment": "prod"]
                    let observability = try OTel.bootstrap(configuration: config)
                    let canary = Canary()
                    let serviceGroup = ServiceGroup(services: [observability, canary], logger: ._otelDebug)

                    try await withThrowingTaskGroup { group in
                        group.addTask {
                            try await serviceGroup.run()
                        }
                        await canary.running
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
                    #expect(message.resourceMetrics.first?.resource.attributes.count == 2)
                    #expect(message.resourceMetrics.first?.resource.attributes.first { $0.key == "service.name" }?.value.stringValue == "innie")
                    #expect(message.resourceMetrics.first?.resource.attributes.first { $0.key == "deployment.environment" }?.value.stringValue == "prod")
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

    @available(gRPCSwift, *)
    @Test func testMetricsGRPCExportUsingBootstrap() async throws {
        /// Note: It's easier to debug this test by commenting out the surrounding `#expect(procesExitsWith:_:)`.
        await #expect(processExitsWith: .success, "Running in a separate process because test uses bootstrap") {
            try await OTLPGRPCMockCollector.withInsecureServer { collector, endpoint in
                try await withThrowingTaskGroup { group in
                    var config = OTel.Configuration.default
                    config.logs.enabled = false
                    config.traces.enabled = false
                    config.metrics.otlpExporter.endpoint = endpoint
                    config.metrics.otlpExporter.protocol = .grpc
                    config.serviceName = "innie"
                    config.resourceAttributes = ["deployment.environment": "prod"]
                    let observability = try OTel.bootstrap(configuration: config)
                    let canary = Canary()
                    let serviceGroup = ServiceGroup(services: [observability, canary], logger: ._otelDebug)
                    group.addTask {
                        try await serviceGroup.run()
                    }
                    await canary.running
                    group.addTask {
                        Gauge(label: "break_room.coffee_temperature").record(85)
                        Counter(label: "macro_data_refinement.files.processed").increment(by: 12)
                        Counter(label: "optics_design.revisions.count").increment(by: 99)
                        await serviceGroup.triggerGracefulShutdown()
                    }
                    try await group.waitForAll()
                }
                #expect(collector.recordingMetricsService.recordingService.requests.count == 1)
                let message = try #require(collector.recordingMetricsService.recordingService.requests.first?.message)
                #expect(message.resourceMetrics.count == 1)
                #expect(message.resourceMetrics.first?.scopeMetrics.count == 1)
                #expect(message.resourceMetrics.first?.scopeMetrics.first?.metrics.count == 3)
                #expect(message.resourceMetrics.first?.resource.attributes.count == 2)
                #expect(message.resourceMetrics.first?.resource.attributes.first { $0.key == "service.name" }?.value.stringValue == "innie")
                #expect(message.resourceMetrics.first?.resource.attributes.first { $0.key == "deployment.environment" }?.value.stringValue == "prod")
            }
        }
    }

    @Test func testLoggingProtobufExportUsingBootstrap() async throws {
        /// Note: It's easier to debug this test by commenting out the surrounding `#expect(procesExitsWith:_:)`.
        await #expect(processExitsWith: .success, "Running in a separate process because test uses bootstrap") {
            try await withThrowingTaskGroup { group in
                let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
                defer { #expect(throws: Never.self) { try testServer.stop() } }

                // Client
                group.addTask {
                    var config = OTel.Configuration.default
                    config.metrics.enabled = false
                    config.traces.enabled = false
                    config.logs.level = .debug
                    config.logs.otlpExporter.endpoint = "http://127.0.0.1:\(testServer.serverPort)/some/path"
                    config.logs.otlpExporter.protocol = .httpProtobuf
                    config.serviceName = "innie"
                    config.resourceAttributes = ["deployment.environment": "prod"]
                    let observability = try OTel.bootstrap(configuration: config)
                    let canary = Canary()
                    // In this test we intentionally disable logging from Service Lifecycle to isolate the user logging.
                    let serviceGroup = ServiceGroup(services: [observability, canary], logger: ._otelDisabled)

                    try await withThrowingTaskGroup { group in
                        group.addTask {
                            try await serviceGroup.run()
                        }
                        await canary.running
                        group.addTask {
                            let logger = Logger(label: "logger")
                            logger.debug(
                                "Waffle party privileges have been revoked due to insufficient team spirit",
                                metadata: ["person": "milchick"]
                            )
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
                    let message = try Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest(serializedBytes: Data(buffer: body))
                    #expect(message.resourceLogs.count == 1)
                    #expect(message.resourceLogs.first?.scopeLogs.count == 1)
                    #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.count == 1)
                    #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.body.stringValue == "Waffle party privileges have been revoked due to insufficient team spirit")
                    #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.attributes.first { $0.key == "person" }?.value.stringValue == "milchick")
                    #expect(message.resourceLogs.first?.resource.attributes.count == 2)
                    #expect(message.resourceLogs.first?.resource.attributes.first { $0.key == "service.name" }?.value.stringValue == "innie")
                    #expect(message.resourceLogs.first?.resource.attributes.first { $0.key == "deployment.environment" }?.value.stringValue == "prod")
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
    }

    @Test func testLoggingJSONExportUsingBootstrap() async throws {
        /// Note: It's easier to debug this test by commenting out the surrounding `#expect(procesExitsWith:_:)`.
        await #expect(processExitsWith: .success, "Running in a separate process because test uses bootstrap") {
            try await withThrowingTaskGroup { group in
                let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
                defer { #expect(throws: Never.self) { try testServer.stop() } }

                // Client
                group.addTask {
                    var config = OTel.Configuration.default
                    config.metrics.enabled = false
                    config.traces.enabled = false
                    config.logs.level = .debug
                    config.logs.otlpExporter.endpoint = "http://127.0.0.1:\(testServer.serverPort)/some/path"
                    config.logs.otlpExporter.protocol = .httpJSON
                    config.serviceName = "innie"
                    config.resourceAttributes = ["deployment.environment": "prod"]
                    let observability = try OTel.bootstrap(configuration: config)
                    let canary = Canary()
                    // In this test we intentionally disable logging from Service Lifecycle to isolate the user logging.
                    let serviceGroup = ServiceGroup(services: [observability, canary], logger: ._otelDisabled)

                    try await withThrowingTaskGroup { group in
                        group.addTask {
                            try await serviceGroup.run()
                        }
                        await canary.running
                        group.addTask {
                            let logger = Logger(label: "logger")
                            logger.debug(
                                "Waffle party privileges have been revoked due to insufficient team spirit",
                                metadata: ["person": "milchick"]
                            )
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
                    let message = try Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest(jsonUTF8Data: Data(buffer: body))
                    #expect(message.resourceLogs.count == 1)
                    #expect(message.resourceLogs.first?.scopeLogs.count == 1)
                    #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.count == 1)
                    #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.body.stringValue == "Waffle party privileges have been revoked due to insufficient team spirit")
                    #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.attributes.first { $0.key == "person" }?.value.stringValue == "milchick")
                    #expect(message.resourceLogs.first?.resource.attributes.count == 2)
                    #expect(message.resourceLogs.first?.resource.attributes.first { $0.key == "service.name" }?.value.stringValue == "innie")
                    #expect(message.resourceLogs.first?.resource.attributes.first { $0.key == "deployment.environment" }?.value.stringValue == "prod")
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

    @available(gRPCSwift, *)
    @Test func testLoggingGRPCExportUsingBootstrap() async throws {
        /// Note: It's easier to debug this test by commenting out the surrounding `#expect(procesExitsWith:_:)`.
        await #expect(processExitsWith: .success, "Running in a separate process because test uses bootstrap") {
            try await OTLPGRPCMockCollector.withInsecureServer { collector, endpoint in
                try await withThrowingTaskGroup { group in
                    var config = OTel.Configuration.default
                    config.metrics.enabled = false
                    config.traces.enabled = false
                    config.logs.level = .debug
                    config.logs.otlpExporter.endpoint = endpoint
                    config.logs.otlpExporter.protocol = .grpc
                    config.serviceName = "innie"
                    config.resourceAttributes = ["deployment.environment": "prod"]
                    config.diagnosticLogLevel = .debug
                    let observability = try OTel.bootstrap(configuration: config)
                    let canary = Canary()
                    // In this test we intentionally disable logging from Service Lifecycle to isolate the user logging.
                    let serviceGroup = ServiceGroup(services: [observability, canary], logger: ._otelDebug)
                    group.addTask {
                        try await serviceGroup.run()
                    }
                    await canary.running
                    group.addTask {
                        let logger = Logger(label: "logger")
                        logger.debug(
                            "Waffle party privileges have been revoked due to insufficient team spirit",
                            metadata: ["person": "milchick"]
                        )
                        await serviceGroup.triggerGracefulShutdown()
                    }
                    try await group.waitForAll()
                }
                #expect(collector.recordingLogsService.recordingService.requests.count == 1)
                let message = try #require(collector.recordingLogsService.recordingService.requests.first?.message)
                #expect(message.resourceLogs.count == 1)
                #expect(message.resourceLogs.first?.scopeLogs.count == 1)
                #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.count == 1)
                #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.body.stringValue == "Waffle party privileges have been revoked due to insufficient team spirit")
                #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.attributes.first { $0.key == "person" }?.value.stringValue == "milchick")
                #expect(message.resourceLogs.first?.resource.attributes.count == 2)
                #expect(message.resourceLogs.first?.resource.attributes.first { $0.key == "service.name" }?.value.stringValue == "innie")
                #expect(message.resourceLogs.first?.resource.attributes.first { $0.key == "deployment.environment" }?.value.stringValue == "prod")
            }
        }
    }

    @Test func testLoggingConsoleExportUsingBootstrap() async throws {
        /// Note: It's easier to debug this test by commenting out the surrounding `#expect(procesExitsWith:_:)`.
        let result = try await #require(processExitsWith: .success, observing: [\.standardOutputContent], "Running in a separate process because test uses bootstrap") {
            var config = OTel.Configuration.default
            config.traces.enabled = false
            config.metrics.enabled = false
            config.logs.exporter = .console
            let observability = try OTel.bootstrap(configuration: config)

            try await withThrowingTaskGroup { group in
                let canary = Canary()
                let serviceGroup = ServiceGroup(services: [observability, canary], logger: ._otelDisabled)
                group.addTask { try await serviceGroup.run() }
                await canary.running
                group.addTask {
                    let logger = Logger(label: "Foo")
                    logger.info(
                        "Waffle party privileges have been revoked due to insufficient team spirit",
                        metadata: ["person": "milchick"]
                    )
                    await serviceGroup.triggerGracefulShutdown()
                }
                try await group.waitForAll()
            }
        }

        let lines = try #require(String(bytes: result.standardOutputContent, encoding: .utf8)).split(separator: "\n")
        let match = try #require(lines.first { $0.contains("Waffle party privileges have been revoked due to insufficient team spirit") })
        #expect(match.contains("person") && match.contains("milchick"))
    }

    @Test func testLogRecordsIncludeSpanContext() async throws {
        /// Note: It's easier to debug this test by commenting out the surrounding `#expect(procesExitsWith:_:)`.
        await #expect(processExitsWith: .success, "Running in a separate process because test uses bootstrap") {
            try await withThrowingTaskGroup { group in
                let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
                defer { #expect(throws: Never.self) { try testServer.stop() } }

                // Client
                group.addTask {
                    var config = OTel.Configuration.default
                    config.metrics.enabled = false
                    config.logs.level = .debug
                    // We use a tiny trace export timeout, otherwise the test will wait until the export timeout is reached.
                    config.traces.otlpExporter.timeout = .nanoseconds(1)
                    config.logs.otlpExporter.endpoint = "http://127.0.0.1:\(testServer.serverPort)/some/path"
                    config.logs.otlpExporter.protocol = .httpJSON
                    config.serviceName = "innie"
                    config.resourceAttributes = ["deployment.environment": "prod"]
                    let observability = try OTel.bootstrap(configuration: config)
                    let canary = Canary()
                    // In this test we intentionally disable logging from Service Lifecycle to isolate the user logging.
                    let serviceGroup = ServiceGroup(services: [observability, canary], logger: ._otelDisabled)

                    try await withThrowingTaskGroup { group in
                        group.addTask {
                            try await serviceGroup.run()
                        }
                        await canary.running
                        group.addTask {
                            let logger = Logger(label: "logger")
                            withSpan("waffle party") { _ in
                                logger.debug(
                                    "Waffle party privileges have been revoked due to insufficient team spirit",
                                    metadata: ["person": "milchick"]
                                )
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
                    let message = try Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest(jsonUTF8Data: Data(buffer: body))
                    let spanID = try #require(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.spanID)
                    #expect(spanID.count == 8 && !spanID.allSatisfy { $0 == 0 })
                    let traceID = try #require(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.traceID)
                    #expect(traceID.count == 16 && !spanID.allSatisfy { $0 == 0 })
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

    @Test func testBootstrapLogsHandoffMessage() async throws {
        let result = try await #require(processExitsWith: .success, observing: [\.standardErrorContent], "Running in a separate process because test uses bootstrap") {
            var config = OTel.Configuration.default
            config.metrics.enabled = false
            config.traces.enabled = false
            Logger(label: "test").info("before bootstrap")
            _ = try OTel.bootstrap(configuration: config)
            Logger(label: "test").info("after bootstrap")
        }
        let lines = try #require(String(bytes: result.standardErrorContent, encoding: .utf8)).split(separator: "\n")
        print(lines.joined(separator: "\n"))
        #expect(lines.contains { $0.contains("before bootstrap") })
        #expect(lines.contains { $0.contains("Only diagnostic logging will use the console") })
        #expect(!lines.contains { $0.contains("after bootstrap") })
    }

    @Test func testLogsIncludeSpanContext() async throws {
        let result = try await #require(processExitsWith: .success, observing: [\.standardErrorContent], "Running in a separate process because test uses bootstrap") {
            var bootstrapConfig = OTel.Configuration.default
            bootstrapConfig.traces.exporter = .none
            bootstrapConfig.diagnosticLogLevel = .trace
            try InstrumentationSystem.bootstrap(OTel.makeTracingBackend(configuration: bootstrapConfig).factory)
            let config = OTel.Configuration.LoggingMetadataProviderConfiguration.default
            let logger = Logger(label: "test") { label in
                StreamLogHandler.standardError(
                    label: label,
                    metadataProvider: OTel.makeLoggingMetadataProvider(configuration: config)
                )
            }
            logger.info("outside")
            withSpan("span") { _ in logger.info("inside") }
        }
        let lines = try #require(String(bytes: result.standardErrorContent, encoding: .utf8)).split(separator: "\n")
        let outside = try #require(lines.first { $0.contains("outside") })
        let inside = try #require(lines.first { $0.contains("inside") })
        for metadataKey in ["span_id", "trace_id", "trace_flags"] {
            #expect(!outside.contains(metadataKey))
            #expect(inside.contains(metadataKey))
        }
    }

    // Cannot use parametrized test because there's a compiler bug preventing the passing of values into exit tests.
    // https://github.com/swiftlang/swift/issues/82783
    @Test func testLogsIncludeSpanContextWithCustomKeys() async throws {
        let result = try await #require(processExitsWith: .success, observing: [\.standardErrorContent], "Running in a separate process because test uses bootstrap") {
            var bootstrapConfig = OTel.Configuration.default
            bootstrapConfig.traces.exporter = .none
            bootstrapConfig.diagnosticLogLevel = .trace
            try InstrumentationSystem.bootstrap(OTel.makeTracingBackend(configuration: bootstrapConfig).factory)
            var config = OTel.Configuration.LoggingMetadataProviderConfiguration.default
            config.spanIDKey = "🔧"
            config.traceIDKey = "🫆"
            config.traceFlagsKey = "🏴‍☠️"
            let logger = Logger(label: "test") { label in
                StreamLogHandler.standardError(
                    label: label,
                    metadataProvider: OTel.makeLoggingMetadataProvider(configuration: config)
                )
            }
            logger.info("outside")
            withSpan("span") { _ in logger.info("inside") }
        }
        let lines = try #require(String(bytes: result.standardErrorContent, encoding: .utf8)).split(separator: "\n")
        let outside = try #require(lines.first { $0.contains("outside") })
        let inside = try #require(lines.first { $0.contains("inside") })
        for metadataKey in ["🔧", "🫆", "🏴‍☠️"] {
            #expect(!outside.contains(metadataKey))
            #expect(inside.contains(metadataKey))
        }
    }

    @Test func testMakeBackendThrowsWhenSignalIsDisabled() throws {
        do {
            let error = try #require(throws: (any Error).self) {
                var config = OTel.Configuration.default
                config.logs.enabled = false
                _ = try OTel.makeLoggingBackend(configuration: config)
            }
            #expect("\(error)" == #"invalidConfiguration("makeLoggingBackend called but config has logs disabled")"#)
        }
        do {
            let error = try #require(throws: (any Error).self) {
                var config = OTel.Configuration.default
                config.metrics.enabled = false
                _ = try OTel.makeMetricsBackend(configuration: config)
            }
            #expect("\(error)" == #"invalidConfiguration("makeMetricsBackend called but config has metrics disabled")"#)
        }
        do {
            let error = try #require(throws: (any Error).self) {
                var config = OTel.Configuration.default
                config.traces.enabled = false
                _ = try OTel.makeTracingBackend(configuration: config)
            }
            #expect("\(error)" == #"invalidConfiguration("makeTracingBackend called but config has traces disabled")"#)
        }
    }
}
#endif // compiler(>=6.2)

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
import OTel
import OTLPCore
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
                    // In this test we intentionally disable logging from Service Lifecycle to isolate the user logging.
                    let serviceGroup = ServiceGroup(services: [observability], logger: ._otelDisabled)

                    try await withThrowingTaskGroup { group in
                        group.addTask {
                            try await serviceGroup.run()
                        }
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
                    #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.body == .init("Waffle party privileges have been revoked due to insufficient team spirit"))
                    #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.attributes.first { $0.key == "person" }?.value == .init("milchick"))
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
                    // In this test we intentionally disable logging from Service Lifecycle to isolate the user logging.
                    let serviceGroup = ServiceGroup(services: [observability], logger: ._otelDisabled)

                    try await withThrowingTaskGroup { group in
                        group.addTask {
                            try await serviceGroup.run()
                        }
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
                    #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.body == .init("Waffle party privileges have been revoked due to insufficient team spirit"))
                    #expect(message.resourceLogs.first?.scopeLogs.first?.logRecords.first?.attributes.first { $0.key == "person" }?.value == .init("milchick"))
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
}
#endif // compiler(>=6.2)

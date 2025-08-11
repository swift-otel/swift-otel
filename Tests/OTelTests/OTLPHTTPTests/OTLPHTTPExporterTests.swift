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

import AsyncHTTPClient
import struct Foundation.Data
import Metrics
import NIOConcurrencyHelpers
import NIOHTTP1
import NIOTestUtils
@testable import OTel
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

    @Test func testRetryPolicyBackoff() async throws {
        var retryPolicy = HTTPClient.RetryPolicy(
            maxAttempts: 7,
            baseDelay: .seconds(1),
            maxDelay: .seconds(10),
            jitter: 0.0
        ) { _ in .retryWithBackoff }
        // Starts with initial delay...
        #expect(retryPolicy.shouldRetry(response: .init()) == .retryAfter(.seconds(1)))
        // ...then delay doubles each time...
        #expect(retryPolicy.shouldRetry(response: .init()) == .retryAfter(.seconds(2)))
        #expect(retryPolicy.shouldRetry(response: .init()) == .retryAfter(.seconds(4)))
        #expect(retryPolicy.shouldRetry(response: .init()) == .retryAfter(.seconds(8)))
        // ...but is clamped to max delay...
        #expect(retryPolicy.shouldRetry(response: .init()) == .retryAfter(.seconds(10)))
        // ...and remains at max delay...
        #expect(retryPolicy.shouldRetry(response: .init()) == .retryAfter(.seconds(10)))
        // ...until max attempts, when retry is denied...
        #expect(retryPolicy.shouldRetry(response: .init()) == .doNotRetry)
        // ...on an ongoing basis.
        #expect(retryPolicy.shouldRetry(response: .init()) == .doNotRetry)
    }

    @Test func testRetryPolicyBackoffWithJitter() async throws {
        var retryPolicy = HTTPClient.RetryPolicy(
            maxAttempts: 7,
            baseDelay: .seconds(1),
            maxDelay: .seconds(10),
            jitter: 0.1
        ) { _ in .retryWithBackoff }
        do {
            let delay = try #require(retryPolicy.shouldRetry(response: .init()).retryDelay)
            #expect(delay != .seconds(1))
            #expect(delay >= .seconds(1) * 0.9)
            #expect(delay <= .seconds(1) * 1.1)
        }
        do {
            let delay = try #require(retryPolicy.shouldRetry(response: .init()).retryDelay)
            #expect(delay != .seconds(2))
            #expect(delay >= .seconds(2) * 0.9)
            #expect(delay <= .seconds(2) * 1.1)
        }
        do {
            let delay = try #require(retryPolicy.shouldRetry(response: .init()).retryDelay)
            #expect(delay != .seconds(4))
            #expect(delay >= .seconds(4) * 0.9)
            #expect(delay <= .seconds(4) * 1.1)
        }
        do {
            let delay = try #require(retryPolicy.shouldRetry(response: .init()).retryDelay)
            #expect(delay != .seconds(8))
            #expect(delay >= .seconds(8) * 0.9)
            #expect(delay <= .seconds(8) * 1.1)
        }
        do {
            let delay = try #require(retryPolicy.shouldRetry(response: .init()).retryDelay)
            #expect(delay != .seconds(10))
            #expect(delay >= .seconds(10) * 0.9)
            #expect(delay <= .seconds(10) * 1.1)
        }
        do {
            let delay = try #require(retryPolicy.shouldRetry(response: .init()).retryDelay)
            #expect(delay != .seconds(10))
            #expect(delay >= .seconds(10) * 0.9)
            #expect(delay <= .seconds(10) * 1.1)
        }
        #expect(retryPolicy.shouldRetry(response: .init()) == .doNotRetry)
        #expect(retryPolicy.shouldRetry(response: .init()) == .doNotRetry)
    }

    @Test func testRetryPolicyPolicyDeclinesRetry() async throws {
        var retryPolicy = HTTPClient.RetryPolicy(
            maxAttempts: 7,
            baseDelay: .seconds(1),
            maxDelay: .seconds(10),
            jitter: 0.0
        ) { _ in .doNotRetry }
        #expect(retryPolicy.shouldRetry(response: .init()) == .doNotRetry)
        #expect(retryPolicy.shouldRetry(response: .init()) == .doNotRetry)
    }

    @Test func testRetryPolicyPolicySpecifiesDelay() async throws {
        var retryPolicy = HTTPClient.RetryPolicy(
            maxAttempts: 3,
            baseDelay: .seconds(1),
            maxDelay: .seconds(10),
            jitter: 0.0
        ) { _ in .retryWithSpecificBackoff(.seconds(42)) }
        #expect(retryPolicy.shouldRetry(response: .init()) == .retryAfter(.seconds(42)))
        #expect(retryPolicy.shouldRetry(response: .init()) == .retryAfter(.seconds(42)))
        #expect(retryPolicy.shouldRetry(response: .init()) == .doNotRetry)
        #expect(retryPolicy.shouldRetry(response: .init()) == .doNotRetry)
    }

    @Test func testRetryCustomPolicyStillBacksOffBasedOnAttempts() async throws {
        // TODO: use an extension on tooManyRequests response
        var retryPolicy = HTTPClient.RetryPolicy(
            maxAttempts: 8,
            baseDelay: .seconds(1),
            maxDelay: .seconds(10),
            jitter: 0.0
        ) { response in
            switch response.status {
            case .tooManyRequests: .retryWithBackoff
            case .imATeapot: .retryWithSpecificBackoff(.seconds(42))
            default: .doNotRetry
            }
        }
        // Starts with initial delay...
        #expect(retryPolicy.shouldRetry(response: .init(status: .tooManyRequests)) == .retryAfter(.seconds(1)))
        // ...then delay doubles each time...
        #expect(retryPolicy.shouldRetry(response: .init(status: .tooManyRequests)) == .retryAfter(.seconds(2)))
        // ...unless specified backoff...
        #expect(retryPolicy.shouldRetry(response: .init(status: .imATeapot)) == .retryAfter(.seconds(42)))
        // ...but considers the above part of the exponential sequence...
        #expect(retryPolicy.shouldRetry(response: .init(status: .tooManyRequests)) == .retryAfter(.seconds(8)))
        // ...but is clamped to max delay...
        #expect(retryPolicy.shouldRetry(response: .init(status: .tooManyRequests)) == .retryAfter(.seconds(10)))
        // ...but still respects specified backoff...
        #expect(retryPolicy.shouldRetry(response: .init(status: .imATeapot)) == .retryAfter(.seconds(42)))
        // ...and goes back to clamped if not specified...
        #expect(retryPolicy.shouldRetry(response: .init(status: .tooManyRequests)) == .retryAfter(.seconds(10)))
        // ...until max attempts, when retry is denied...
        #expect(retryPolicy.shouldRetry(response: .init(status: .tooManyRequests)) == .doNotRetry)
        // ...on an ongoing basis, even if specified backoff.
        #expect(retryPolicy.shouldRetry(response: .init(status: .imATeapot)) == .doNotRetry)
    }

    @Test func testHTTPClientWithRetryPolicyMaxAttempts() async throws {
        let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
        defer { #expect(throws: Never.self) { try? testServer.stop() } }

        let clock = TestClock()
        let numRequestsReceivedByServer = NIOLockedValueBox(0)

        try await withThrowingTaskGroup { group in
            group.addTask { // client
                try await HTTPClient.withHTTPClient { client in
                    var request = HTTPClientRequest(url: "http://127.0.0.1:\(testServer.serverPort)/some/path")
                    request.method = .POST
                    request.body = .init(.bytes(.init(string: "hello")))
                    let retryPolicy = HTTPClient.RetryPolicy(
                        maxAttempts: 3,
                        baseDelay: .seconds(1),
                        maxDelay: .seconds(10),
                        jitter: 0.0
                    ) { response in
                        switch response.status {
                        case .tooManyRequests:
                            if let retryAfter = response.headers["Retry-After"].last.flatMap(Int.init) {
                                .retryWithSpecificBackoff(.seconds(retryAfter))
                            } else {
                                .retryWithBackoff
                            }
                        default: .doNotRetry
                        }
                    }
                    let response = try await client.execute(
                        request,
                        timeout: .seconds(60),
                        logger: ._otelDebug,
                        clock: clock,
                        retryPolicy: retryPolicy
                    )
                    #expect(response.status == .tooManyRequests)
                    #expect(numRequestsReceivedByServer.withLockedValue { $0 } == 3)
                }
            }
            group.addTask { // server
                var sleepCalls = clock.sleepCalls.makeAsyncIterator()
                // For the max attempts, return too many requests.
                for _ in 1 ... 3 {
                    _ = try testServer.receiveHead()
                    _ = try testServer.receiveBody()
                    _ = try testServer.receiveEnd()
                    numRequestsReceivedByServer.withLockedValue { $0 += 1 }
                    try testServer.writeOutbound(.head(.init(version: .http1_1, status: .tooManyRequests, headers: ["Retry-After": "42"])))
                    try testServer.writeOutbound(.body(.byteBuffer(.init())))
                    try testServer.writeOutbound(.end(nil))
                    await sleepCalls.next()
                    clock.advance(by: .seconds(42))
                }
                while !Task.isCancelled { await Task.yield() }
            }
            try await group.next()
            group.cancelAll()
            try await group.waitForAll()
        }
    }

    @Test func testHTTPClientWithRetryPolicyFirstRequestSucceeds() async throws {
        let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
        defer { #expect(throws: Never.self) { try? testServer.stop() } }

        let clock = TestClock()
        let numRequestsReceivedByServer = NIOLockedValueBox(0)

        try await withThrowingTaskGroup { group in
            group.addTask { // client
                try await HTTPClient.withHTTPClient { client in
                    var request = HTTPClientRequest(url: "http://127.0.0.1:\(testServer.serverPort)/some/path")
                    request.method = .POST
                    request.body = .init(.bytes(.init(string: "hello")))
                    let retryPolicy = HTTPClient.RetryPolicy(
                        maxAttempts: 3,
                        baseDelay: .seconds(1),
                        maxDelay: .seconds(10),
                        jitter: 0.0
                    ) { response in
                        switch response.status {
                        case .tooManyRequests:
                            if let retryAfter = response.headers["Retry-After"].last.flatMap(Int.init) {
                                .retryWithSpecificBackoff(.seconds(retryAfter))
                            } else {
                                .retryWithBackoff
                            }
                        default: .doNotRetry
                        }
                    }
                    let response = try await client.execute(request, timeout: .seconds(60), clock: clock, retryPolicy: retryPolicy)
                    #expect(response.status == .ok)
                    #expect(numRequestsReceivedByServer.withLockedValue { $0 } == 1)
                }
            }
            group.addTask { // server
                // Return OK.
                _ = try testServer.receiveHead()
                _ = try testServer.receiveBody()
                _ = try testServer.receiveEnd()
                numRequestsReceivedByServer.withLockedValue { $0 += 1 }
                try testServer.writeOutbound(.head(.init(version: .http1_1, status: .ok)))
                try testServer.writeOutbound(.body(.byteBuffer(.init())))
                try testServer.writeOutbound(.end(nil))
                while !Task.isCancelled { await Task.yield() }
            }
            try await group.next()
            group.cancelAll()
            try await group.waitForAll()
        }
    }

    @Test func testHTTPClientWithRetryPolicyRetrySucceeds() async throws {
        let testServer = NIOHTTP1TestServer(group: .singletonMultiThreadedEventLoopGroup)
        defer { #expect(throws: Never.self) { try? testServer.stop() } }

        let clock = TestClock()
        let numRequestsReceivedByServer = NIOLockedValueBox(0)

        try await withThrowingTaskGroup { group in
            group.addTask { // client
                try await HTTPClient.withHTTPClient { client in
                    var request = HTTPClientRequest(url: "http://127.0.0.1:\(testServer.serverPort)/some/path")
                    request.method = .POST
                    request.body = .init(.bytes(.init(string: "hello")))
                    let retryPolicy = HTTPClient.RetryPolicy(
                        maxAttempts: 3,
                        baseDelay: .seconds(1),
                        maxDelay: .seconds(10),
                        jitter: 0.0
                    ) { response in
                        switch response.status {
                        case .tooManyRequests:
                            if let retryAfter = response.headers["Retry-After"].last.flatMap(Int.init) {
                                .retryWithSpecificBackoff(.seconds(retryAfter))
                            } else {
                                .retryWithBackoff
                            }
                        default: .doNotRetry
                        }
                    }
                    let response = try await client.execute(request, timeout: .seconds(60), clock: clock, retryPolicy: retryPolicy)
                    #expect(response.status == .ok)
                    #expect(numRequestsReceivedByServer.withLockedValue { $0 } == 2)
                }
            }
            group.addTask { // server
                var sleepCalls = clock.sleepCalls.makeAsyncIterator()
                // For one request, return too many requests.
                _ = try testServer.receiveHead()
                _ = try testServer.receiveBody()
                _ = try testServer.receiveEnd()
                numRequestsReceivedByServer.withLockedValue { $0 += 1 }
                try testServer.writeOutbound(.head(.init(version: .http1_1, status: .tooManyRequests, headers: ["Retry-After": "1"])))
                try testServer.writeOutbound(.body(.byteBuffer(.init())))
                try testServer.writeOutbound(.end(nil))
                // Wait for backoff to sleep, then advance clock by retry delay.
                await sleepCalls.next()
                clock.advance(by: .seconds(1))
                // Then return OK.
                _ = try testServer.receiveHead()
                _ = try testServer.receiveBody()
                _ = try testServer.receiveEnd()
                numRequestsReceivedByServer.withLockedValue { $0 += 1 }
                try testServer.writeOutbound(.head(.init(version: .http1_1, status: .ok)))
                try testServer.writeOutbound(.body(.byteBuffer(.init())))
                try testServer.writeOutbound(.end(nil))
            }
            try await group.next()
            group.cancelAll()
            try await group.waitForAll()
        }
    }

    @Test func testOTelSpecRetryPolicy() {
        /// The requests that receive a response status code listed in following table SHOULD be retried. All other 4xx or 5xx response status codes MUST NOT be retried.
        /// — source: https://opentelemetry.io/docs/specs/otlp/#retryable-response-codes
        for code in 100 ... 599 {
            let responseWithoutHeader = HTTPClientResponse(status: .init(statusCode: code))
            let responseWithHeader = HTTPClientResponse(status: .init(statusCode: code), headers: ["Retry-After": "42"])
            var policy = HTTPClient.RetryPolicy.otel
            switch code {
            case 429, 502, 503, 504:
                guard case .retryAfter(let delay) = policy.shouldRetry(response: responseWithoutHeader) else {
                    Issue.record("OTel HTTP retry policy should retry for status code: \(code).")
                    continue
                }
                #expect(delay != .seconds(1))
                #expect(delay >= .seconds(0.9))
                #expect(delay <= .seconds(1.1))
                guard case .retryAfter(let delay) = policy.shouldRetry(response: responseWithHeader) else {
                    Issue.record("OTel HTTP retry policy should retry for status code: \(code).")
                    continue
                }
                #expect(delay == .seconds(42))
            default:
                #expect(policy.shouldRetry(response: responseWithoutHeader) == .doNotRetry)
                #expect(policy.shouldRetry(response: responseWithHeader) == .doNotRetry)
            }
        }
    }
}

extension HTTPClient.RetryPolicy.RetryDecision {
    var retryDelay: Duration? {
        guard case .retryAfter(let delay) = self else { return nil }
        return delay
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

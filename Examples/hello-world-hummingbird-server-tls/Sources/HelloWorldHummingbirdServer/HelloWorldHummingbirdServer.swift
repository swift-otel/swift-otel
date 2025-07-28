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

import Hummingbird
import OTel

import struct Foundation.URL

@main
enum HelloWorldHummingbirdServer {
    static func main() async throws {
        // Bootstrap observability backends (with short export intervals for demo purposes).
        var config = OTel.Configuration.default
        config.serviceName = "hello_world"
        config.diagnosticLogLevel = .error
        config.logs.batchLogRecordProcessor.scheduleDelay = .seconds(3)
        config.metrics.exportInterval = .seconds(3)
        config.traces.batchSpanProcessor.scheduleDelay = .seconds(3)
        config.logs.otlpExporter.endpoint = "https://localhost:4318/v1/logs"
        config.metrics.otlpExporter.endpoint = "https://localhost:4318/v1/metrics"
        config.traces.otlpExporter.endpoint = "https://localhost:4318/v1/traces"
        let certPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(components: "certs", "chain.crt").path(percentEncoded: false)
        config.logs.otlpExporter.certificateFilePath = certPath
        config.metrics.otlpExporter.certificateFilePath = certPath
        config.traces.otlpExporter.certificateFilePath = certPath
        let observability = try OTel.bootstrap(configuration: config)

        // Create an HTTP server with instrumentation middlewares added.
        let router = Router()
        router.middlewares.add(TracingMiddleware())
        router.middlewares.add(MetricsMiddleware())
        router.middlewares.add(LogRequestsMiddleware(.info))
        router.get("hello") { _, _ in "hello" }
        var app = Application(router: router)

        // Add the observability service to the Hummingbird service group and run the server.
        app.addServices(observability)
        try await app.runService()
    }
}

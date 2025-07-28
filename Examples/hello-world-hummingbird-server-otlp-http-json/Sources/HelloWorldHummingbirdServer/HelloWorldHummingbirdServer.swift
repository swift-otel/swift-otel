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
        config.logs.otlpExporter.protocol = .httpJSON
        config.metrics.otlpExporter.protocol = .httpJSON
        config.traces.otlpExporter.protocol = .httpJSON
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

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
import Logging
import OTel

@main
enum HelloWorldHummingbirdServer {
    static func main() async throws {
        // Bootstrap only the tracing backend (logs and metrics OTLP backends disabled).
        var config = OTel.Configuration.default
        config.serviceName = "hello_world"
        config.diagnosticLogLevel = .error
        config.logs.enabled = false
        config.metrics.enabled = false
        config.traces.batchSpanProcessor.scheduleDelay = .seconds(3)
        let observability = try OTel.bootstrap(configuration: config)

        // Bootstrap the logging backend using stderr, with OTel span metadata.
        LoggingSystem.bootstrap(
            StreamLogHandler.standardError(label:metadataProvider:),
            metadataProvider: OTel.makeLoggingMetadataProvider()
        )

        // Create an HTTP server with instrumentation middlewares added.
        let router = Router()
        router.middlewares.add(TracingMiddleware())
        router.middlewares.add(LogRequestsMiddleware(.info))
        router.get("hello") { _, _ in "hello" }
        var app = Application(router: router)

        // Add the observability service to the Hummingbird service group and run the server.
        app.addServices(observability)
        try await app.runService()
    }
}

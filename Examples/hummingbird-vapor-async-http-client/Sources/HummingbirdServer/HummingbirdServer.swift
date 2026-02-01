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
import Hummingbird
import OTel
import Tracing

@main
enum HummingbirdServer {
    static func main() async throws {
        // Bootstrap observability backends (with short export intervals for demo purposes).
        var config = OTel.Configuration.default
        config.serviceName = "hummingbird"
        config.diagnosticLogLevel = .error
        config.logs.batchLogRecordProcessor.scheduleDelay = .seconds(3)
        config.metrics.exportInterval = .seconds(3)
        config.traces.batchSpanProcessor.scheduleDelay = .seconds(3)
        let observability = try OTel.bootstrap(configuration: config)

        // Create an HTTP server with instrumentation middlewares added.
        let router = Router()
        router.middlewares.add(TracingMiddleware())
        router.middlewares.add(MetricsMiddleware())
        router.middlewares.add(LogRequestsMiddleware(.info))
        router.get("hello") { _, context in
            try await Task.sleep(for: .seconds(0.5))
            context.logger.info("Sending request to Vapor.")
            let response = try await HTTPClient.shared.execute(
                HTTPClientRequest(url: "http://localhost:8081/hello"),
                timeout: .seconds(10),
            )
            let payload = try await response.body.collect(upTo: 1000)
            context.logger.info("Received response from Vapor.")
            return payload
        }
        var app = Application(router: router)

        // Add the observability service to the Hummingbird service group and run the server.
        app.addServices(observability)
        try await app.runService()
    }
}

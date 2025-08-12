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

import OTel
import Vapor

@main
enum HelloWorldVaporServer {
    static func main() async throws {
        // Bootstrap observability backends (with short export intervals for demo purposes).
        var config = OTel.Configuration.default
        config.serviceName = "hello_world"
        config.diagnosticLogLevel = .error
        config.logs.batchLogRecordProcessor.scheduleDelay = .seconds(3)
        config.metrics.exportInterval = .seconds(3)
        config.traces.batchSpanProcessor.scheduleDelay = .seconds(3)
        let observability = try OTel.bootstrap(configuration: config)

        // Create an HTTP server with instrumentation middlewares added.
        let app = try await Vapor.Application.make()
        app.middleware.use(TracingMiddleware())
        app.traceAutoPropagation = true
        app.middleware.use(RouteLoggingMiddleware(logLevel: .info))
        app.get("hello") { _ in "hello" }

        // Run the observability service in a task group with the Vapor server.
        try await withThrowingTaskGroup { group in
            group.addTask { try await observability.run() }
            group.addTask { try await app.execute() }
            try await group.next()
            group.cancelAll()
            try await group.waitForAll()
        }
    }
}

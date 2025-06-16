//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2024 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird
import Logging
import Metrics
import OTel
import Tracing

@main
enum ServerMiddlewareExample {
    static func main() async throws {
        // Bootstrap the observability backends with default configuration.
        // TODO: Uncomment this line when the 1.0 API is ready.
        // let observability = try OTel.bootstrap()
        let observability: ServiceGroup! = nil

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

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

import Logging
import OTel
import ServiceLifecycle
import Tracing

@main
enum Example {
    static func main() async throws {
        // Bootstrap the observability backends with default configuration.
        // TODO: Uncomment this line when the 1.0 API is ready.
        // let observability = try OTel.bootstrap()
        let observability: ServiceGroup! = nil

        // Create your services that use the Swift observability API packages for instrumentation.
        let service = Counter()

        // Add the observability and exmaple services to a service group and run.
        let serviceGroup = ServiceGroup(
            services: [observability, service],
            gracefulShutdownSignals: [.sigint],
            logger: Logger(label: "Example")
        )
        try await serviceGroup.run()
    }
}

struct Counter: Service, CustomStringConvertible {
    let description = "Example"

    private let stream: AsyncStream<Int>
    private let continuation: AsyncStream<Int>.Continuation

    private let logger = Logger(label: "Counter")

    init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    func run() async {
        continuation.yield(0)

        for await value in stream.cancelOnGracefulShutdown() {
            let delay = Duration.seconds(.random(in: 0 ..< 1))

            do {
                try await withSpan("count") { span in
                    if value % 10 == 0 {
                        logger.error("Failed to count up, skipping value.", metadata: ["value": "\(value)"])
                        span.recordError(CounterError.failedIncrementing(value: value))
                        span.setStatus(.init(code: .error))
                        continuation.yield(value + 1)
                    } else {
                        span.attributes["value"] = value
                        logger.info("Counted up.", metadata: ["count": "\(value)"])
                        try await Task.sleep(for: delay)
                        continuation.yield(value + 1)
                    }
                }
            } catch {
                return
            }
        }
    }
}

enum CounterError: Error {
    case failedIncrementing(value: Int)
}

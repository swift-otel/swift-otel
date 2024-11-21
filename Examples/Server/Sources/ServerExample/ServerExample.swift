//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2024 Moritz Lang and the Swift OTel project authors
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
@_spi(Logging) import OTel
@_spi(Logging) import OTLPGRPC
import ServiceLifecycle
import Tracing

@main
enum ServerMiddlewareExample {
    static func main() async throws {
        // Configure OTel resource detection to automatically apply helpful attributes to events.
        let environment = OTelEnvironment.detected()
        let resourceDetection = OTelResourceDetection(detectors: [
            OTelProcessResourceDetector(),
            OTelEnvironmentResourceDetector(environment: environment),
            .manual(OTelResource(attributes: ["service.name": "example_server"])),
        ])
        let resource = await resourceDetection.resource(environment: environment, logLevel: .trace)

        // Bootstrap the metrics backend to export metrics periodically in OTLP/gRPC.
        let registry = OTelMetricRegistry()
        let metricsExporter = try OTLPGRPCMetricExporter(configuration: .init(environment: environment))
        let metrics = OTelPeriodicExportingMetricsReader(
            resource: resource,
            producer: registry,
            exporter: metricsExporter,
            configuration: .init(
                environment: environment,
                exportInterval: .seconds(5) // NOTE: This is overridden for the example; the default is 60 seconds.
            )
        )
        MetricsSystem.bootstrap(OTLPMetricsFactory(registry: registry))

        // Bootstrap the logging backend with the OTel metadata provider which includes span IDs in logging messages.
        let logExporter = try OTLPGRPCLogEntryExporter(
            configuration: .init(environment: environment)
        )

        let logProcessor = OTelBatchLogRecordProcessor(
            exporter: logExporter,
            configuration: OTelBatchLogEntryProcessorConfiguration(environment: environment)
        )

        let logger = OTelLogHandler(processor: logProcessor, logLevel: .debug, resource: resource)
        LoggingSystem.bootstrap { label in
            return logger
        }

        // Bootstrap the tracing backend to export traces periodically in OTLP/gRPC.
        let traceExporter = try OTLPGRPCSpanExporter(configuration: .init(environment: environment))
        let traceProcessor = OTelBatchSpanProcessor(exporter: traceExporter, configuration: .init(environment: environment))
        let tracer = OTelTracer(
            idGenerator: OTelRandomIDGenerator(),
            sampler: OTelConstantSampler(isOn: true),
            propagator: OTelW3CPropagator(),
            processor: traceProcessor,
            environment: environment,
            resource: resource
        )
        InstrumentationSystem.bootstrap(tracer)

        // Create an HTTP server with instrumentation middleware and a simple /hello endpoint, on 127.0.0.1:8080.
        let router = Router()
        router.middlewares.add(TracingMiddleware())
        router.middlewares.add(MetricsMiddleware())
        router.middlewares.add(LogRequestsMiddleware(.info))
        router.get("hello") { _, context in
            context.logger.info("Someone visited me, at last!")
            return "hello"
        }
        var app = Application(router: router)
        app.logger.logLevel = .debug

        // Add the logger, metrics and tracer lifecycle services to the HTTP server service group and start the application.
        app.addServices(logProcessor, metrics, tracer)
        try await app.runService()
    }
}

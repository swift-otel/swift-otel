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

public import CoreMetrics
public import Logging
public import OTelCore
public import ServiceLifecycle
public import Tracing
#if OTLPGRPC
import OTLPGRPC
#endif
#if OTLPHTTP
import OTLPHTTP
#endif

extension OTel {
    /// Create a logging backend with an OTLP exporter.
    ///
    /// - Parameter configuration: Configuration for the logging backend.
    ///
    ///   This value can be used to configure the logging backend and defaults to `OTel.Configuration.default`, which
    ///   creates a backend with the default configuration defined in the OpenTelemetry specification.
    ///
    ///   Configuration can also be provided at runtime with environment variable overrides.
    ///
    /// - Returns: A tuple containing the logging factory and background service:
    ///
    ///   - `factory`: A factory that can be used to bootstrap the process-global `LoggingSystem`.
    ///
    ///   - `service`: A service that manages the background work, and graceful shutdown of exporters and processors.
    ///
    ///   > Important: The factory has NOT been bootstrapped with the `LoggingSystem` and must be manually registered or
    ///     composed with other logging backends.
    ///
    ///   > Important: You must run the returned service in a `ServiceGroup` alongside your application services for log
    ///     records to be exported.
    ///
    /// > Note: Use this API only if you need combine the logging backend with other functionality or control the
    ///   bootstrap of the logging subsystem. If you do not need this level of control, use
    ///   `OTel.bootstrap(configuration:)`. You do not need to use this API to bootstrap just a subset of observability
    ///   subsystems, which is supported by `OTel.bootstrap(configuration:)`.
    ///
    /// This API creates a factory that can be used to manually bootstrap the process-global logging subsystem.
    ///
    /// This API supports overriding the configuration using environment variables defined in the OpenTelemetry
    /// specification. This enables operators to customize the observability of your application during deployment.
    /// For more details on the configuration options, their defaults, and their associated environment variables, see
    /// `OTel.Configuration`.
    ///
    /// > Warning: Attempting to bootstrap the global `LoggingSystem` multiple times will result in a
    ///   fatal error. Ensure you only bootstrap once per process, either using `OTel.bootstrap(configuration:)` or
    ///   by manually calling `LoggingSystem.bootstrap(_:)` with a backend created by this function.
    ///
    /// ## Example usage
    ///
    /// ### Create and bootstrap the logging backend manually
    ///
    /// ```swift
    /// // Create the logging backend without bootstrapping.
    /// let loggingBackend = try OTel.makeLoggingBackend()
    ///
    /// // Manually bootstrap the logging subsystem.
    /// LoggingSystem.bootstrap(loggingBackend.factory)
    ///
    /// // Run the background service alongside your application.
    /// let server = MockService(name: "AdopterServer")
    /// let serviceGroup = ServiceGroup(
    ///     services: [loggingBackend.service, server],
    ///     logger: .init(label: "ServiceGroup")
    /// )
    /// try await serviceGroup.run()
    /// ```
    ///
    /// ### Multiplex with other logging backends
    ///
    /// ```swift
    /// // Create the logging backend without bootstrapping.
    /// let otelBackend = try OTel.makeLoggingBackend()
    ///
    /// // Manually bootstrap the logging subsystem with a multiplex handler.
    /// LoggingSystem.bootstrap({ label in
    ///     MultiplexLogHandler([
    ///        otelBackend.factory(label),
    ///        SwiftLogNoOpLogHandler(label)
    ///     ])
    /// })
    ///
    /// // Run the background service alongside your application.
    /// let server = MockService(name: "AdopterServer")
    /// let serviceGroup = ServiceGroup(
    ///     services: [otelBackend.service, server],
    ///     logger: .init(label: "ServiceGroup")
    /// )
    /// try await serviceGroup.run()
    /// ```
    ///
    /// - SeeAlso:
    ///   - `OTel.bootstrap(configuration:)` for simple, all-in-one observability setup
    ///   - `OTel.makeMetricsBackend(configuration:)` for metrics backend creation
    ///   - `OTel.makeTracingBackend(configuration:)` for tracing backend creation
    ///   - `OTel.Configuration` for configuration options and environment variables
    public static func makeLoggingBackend(configuration: OTel.Configuration = .default) throws -> (factory: @Sendable (String) -> any LogHandler, service: some Service) {
        /// This is necessary because the processor is generic over the exporter and we need to return an opaque type.
        struct Wrapper: Service {
            var wrapped: any Service
            func run() async throws {
                try await wrapped.run()
            }
        }

        let logger = Logger(label: "swift-otel")
        let resource = OTelResource(configuration: configuration)
        switch configuration.logs.exporter.backing {
        case .otlp:
            switch configuration.logs.otlpExporter.protocol.backing {
            case .grpc:
                #if OTLPGRPC
                let exporter = try OTLPGRPCLogRecordExporter(configuration: configuration.logs.otlpExporter, logger: logger)
                let processor = OTelBatchLogRecordProcessor(exporter: exporter, configuration: .init(configuration: configuration.logs.batchLogRecordProcessor), logger: logger)
                let handler = OTelLogHandler(
                    processor: processor,
                    logLevel: Logger.Level(configuration.logs.level),
                    resource: resource
                )
                return ({ _ in handler }, Wrapper(wrapped: processor))
                #else // OTLPGRPC
                fatalError("Using the OTLP/GRPC exporter requires the `OTLPGRPC` trait enabled.")
                #endif
            case .httpProtobuf, .httpJSON:
                #if OTLPHTTP
                let exporter = try OTLPHTTPLogRecordExporter(configuration: configuration.logs.otlpExporter, logger: logger)
                let processor: OTelBatchLogRecordProcessor = .init(
                    exporter: exporter,
                    configuration: OTelBatchLogRecordProcessorConfiguration(environment: .detected()), // TODO: shim,
                    logger: logger
                )
                let handler = OTelLogHandler(
                    processor: processor,
                    logLevel: Logger.Level(configuration.logs.level),
                    resource: resource
                )
                return ({ _ in handler }, Wrapper(wrapped: processor))
                #else
                fatalError("Using the OTLP/HTTP + Protobuf exporter requires the `OTLPHTTP` trait enabled.")
                #endif
            }
        case .console:
            throw NotImplementedError()
        }
    }

    /// Create a metrics backend with an OTLP exporter.
    ///
    /// - Parameter configuration: Configuration for the metrics backend.
    ///
    ///   This value can be used to configure the metrics backend and defaults to `OTel.Configuration.default`, which
    ///   creates a backend with the default configuration defined in the OpenTelemetry specification.
    ///
    ///   Configuration can also be provided at runtime with environment variable overrides.
    ///
    /// - Returns: A tuple containing the metrics factory and background service:
    ///
    ///   - `factory`: A factory that can be used to bootstrap the process-global `MetricsSystem`.
    ///
    ///   - `service`: A service that manages the background work, and graceful shutdown of exporters and processors.
    ///
    ///   > Important: The factory has NOT been bootstrapped with the `MetricsSystem` and must be manually
    ///     registered or composed with other metrics backends.
    ///
    ///   > Important: You must run the returned service in a `ServiceGroup` alongside your application
    ///     services for metrics to be exported.
    ///
    /// > Note: Use this API only if you need combine the metrics backend with other functionality or control the
    ///   bootstrap of the metrics subsystem. If you do not need this level of control, use
    ///   `OTel.bootstrap(configuration:)`. You do not need to use this API to bootstrap just a subset of observability
    ///   subsystems, which is supported by `OTel.bootstrap(configuration:)`.
    ///
    /// This API creates a factory that can be used to manually bootstrap the process-global metrics subsystem.
    ///
    /// This API supports overriding the configuration using environment variables defined in the OpenTelemetry
    /// specification. This enables operators to customize the observability of your application during deployment.
    /// For more details on the configuration options, their defaults, and their associated environment variables, see
    /// `OTel.Configuration`.
    ///
    /// > Warning: Attempting to bootstrap the global `MetricsSystem` multiple times will result in a
    ///   fatal error. Ensure you only bootstrap once per process, either using `OTel.bootstrap(configuration:)` or
    ///   by manually calling `MetricsSystem.bootstrap(_:)` with a backend created by this function.
    ///
    /// ## Example usage
    ///
    /// ### Create and bootstrap the metrics backend manually
    ///
    /// ```swift
    /// // Create the metrics backend without bootstrapping.
    /// let metricsBackend = try OTel.makeMetricsBackend()
    ///
    /// // Manually bootstrap the metrics subsystem.
    /// MetricsSystem.bootstrap(metricsBackend.factory)
    ///
    /// // Run the background service alongside your application.
    /// let server = MockService(name: "AdopterServer")
    /// let serviceGroup = ServiceGroup(
    ///     services: [metricsBackend.service, server],
    ///     logger: .init(label: "ServiceGroup")
    /// )
    /// try await serviceGroup.run()
    /// ```
    ///
    /// ### Multiplex with other metrics backends
    ///
    /// ```swift
    /// // Create the metrics backend without bootstrapping.
    /// let otelBackend = try OTel.makeMetricsBackend()
    ///
    /// // Manually bootstrap the metrics subsystem with a multiplex handler.
    /// MetricsSystem.bootstrap({ label in
    ///     MultiplexMetricsHandler([
    ///        otelBackend.factory(label),
    ///        NOOPMetricsHandler.instance
    ///     ])
    /// })
    ///
    /// // Run the background service alongside your application.
    /// let server = MockService(name: "AdopterServer")
    /// let serviceGroup = ServiceGroup(
    ///     services: [otelBackend.service, server],
    ///     logger: .init(label: "ServiceGroup")
    /// )
    /// try await serviceGroup.run()
    /// ```
    ///
    /// - SeeAlso:
    ///   - `OTel.bootstrap(configuration:)` for simple, all-in-one observability setup
    ///   - `OTel.makeLoggingBackend(configuration:)` for logging backend creation
    ///   - `OTel.makeTracingBackend(configuration:)` for tracing backend creation
    ///   - `OTel.Configuration` for configuration options and environment variables
    public static func makeMetricsBackend(configuration: OTel.Configuration = .default) throws -> (factory: any MetricsFactory, service: some Service) {
        let logger = Logger(label: "swift-otel")
        let resource = OTelResource(configuration: configuration)
        let registry = OTelMetricRegistry(logger: logger)
        let metricsExporter: OTelMetricExporter
        switch configuration.metrics.exporter.backing {
        case .otlp:
            switch configuration.metrics.otlpExporter.protocol.backing {
            case .grpc:
                #if OTLPGRPC
                metricsExporter = try OTLPGRPCMetricExporter(configuration: configuration.metrics.otlpExporter, logger: logger)
                #else // OTLPGRPC
                fatalError("Using the OTLP/GRPC exporter requires the `OTLPGRPC` trait enabled.")
                #endif
            case .httpProtobuf, .httpJSON:
                #if OTLPHTTP
                metricsExporter = try OTLPHTTPMetricExporter(configuration: configuration.metrics.otlpExporter, logger: logger)
                #else
                fatalError("Using the OTLP/HTTP + Protobuf exporter requires the `OTLPHTTP` trait enabled.")
                #endif
            }
        case .console:
            metricsExporter = OTelConsoleMetricExporter()
        case .prometheus:
            fatalError("Swift OTel does not support the Prometheus exporter")
        }

        let readerConfig = OTelPeriodicExportingMetricsReaderConfiguration(configuration: configuration.metrics)

        let reader = OTelPeriodicExportingMetricsReader(resource: resource, producer: registry, exporter: metricsExporter, configuration: readerConfig, logger: logger)

        return (OTLPMetricsFactory(registry: registry), reader)
    }

    /// Create a tracing backend with an OTLP exporter.
    ///
    /// - Parameter configuration: Configuration for the tracing backend.
    ///
    ///   This value can be used to configure the tracing backend and defaults to `OTel.Configuration.default`, which
    ///   creates a backend with the default configuration defined in the OpenTelemetry specification.
    ///
    ///   Configuration can also be provided at runtime with environment variable overrides.
    ///
    /// - Returns: A tuple containing the tracing factory and background service:
    ///
    ///   - `factory`: A factory that can be used to bootstrap the process-global `InstrumentationSystem`.
    ///
    ///   - `service`: A service that manages the background work, and graceful shutdown of exporters and processors.
    ///
    ///   > Important: The factory has NOT been bootstrapped with the `InstrumentationSystem` and must be manually
    ///     registered or composed with other tracing backends.
    ///
    ///   > Important: You must run the returned service in a `ServiceGroup` alongside your application
    ///     services for traces to be exported.
    ///
    /// > Note: Use this API only if you need combine the tracing backend with other functionality or control the
    ///   bootstrap of the tracing subsystem. If you do not need this level of control, use
    ///   `OTel.bootstrap(configuration:)`. You do not need to use this API to bootstrap just a subset of observability
    ///   subsystems, which is supported by `OTel.bootstrap(configuration:)`.
    ///
    /// This API creates a factory that can be used to manually bootstrap the process-global tracing subsystem.
    ///
    /// This API supports overriding the configuration using environment variables defined in the OpenTelemetry
    /// specification. This enables operators to customize the observability of your application during deployment.
    /// For more details on the configuration options, their defaults, and their associated environment variables, see
    /// `OTel.Configuration`.
    ///
    /// > Warning: Attempting to bootstrap the global `InstrumentationSystem` multiple times will result in a
    ///   fatal error. Ensure you only bootstrap once per process, either using `OTel.bootstrap(configuration:)` or
    ///   by manually calling `InstrumentationSystem.bootstrap(_:)` with a backend created by this function.
    ///
    /// ## Example usage
    ///
    /// ### Create and bootstrap the tracing backend manually
    ///
    /// ```swift
    /// // Create the tracing backend without bootstrapping.
    /// let tracingBackend = try OTel.makeTracingBackend()
    ///
    /// // Manually bootstrap the tracing subsystem.
    /// InstrumentationSystem.bootstrap(tracingBackend.factory)
    ///
    /// // Run the background service alongside your application.
    /// let server = MockService(name: "AdopterServer")
    /// let serviceGroup = ServiceGroup(
    ///     services: [tracingBackend.service, server],
    ///     logger: .init(label: "ServiceGroup")
    /// )
    /// try await serviceGroup.run()
    /// ```
    ///
    /// ### Multiplex with other tracing backends
    ///
    /// ```swift
    /// // Create the tracing backend without bootstrapping.
    /// let otelBackend = try OTel.makeTracingBackend()
    ///
    /// // Manually bootstrap the tracing subsystem with a multiplex handler.
    /// InstrumentationSystem.bootstrap({ label in
    ///     MultiplexInstrument([
    ///        otelBackend.factory(label),
    ///        NoOpTracer()
    ///     ])
    /// })
    ///
    /// // Run the background service alongside your application.
    /// let server = MockService(name: "AdopterServer")
    /// let serviceGroup = ServiceGroup(
    ///     services: [otelBackend.service, server],
    ///     logger: .init(label: "ServiceGroup")
    /// )
    /// try await serviceGroup.run()
    /// ```
    ///
    /// - SeeAlso:
    ///   - `OTel.bootstrap(configuration:)` for simple, all-in-one observability setup
    ///   - `OTel.makeLoggingBackend(configuration:)` for logging backend creation
    ///   - `OTel.makeMetricsBackend(configuration:)` for metrics backend creation
    ///   - `OTel.Configuration` for configuration options and environment variables
    public static func makeTracingBackend(configuration: OTel.Configuration = .default) throws -> (factory: any Tracer, service: some Service) {
        /// This dance is necessary if we want to continue to return `some Service` (vs. returning `any Service`).
        ///
        /// This is also only necessary for tracing because the Tracer is generic over the processor, which, in turn, is
        /// generic over the exporter. The metrics internals use an existential exporter.
        ///
        /// For now, in order to preserve the shape of both metrics and traces types, and because there's only a closed
        /// set of types that are expressible by config, we'll return an enum wrapper as our opaque return type.
        struct TracerWrapper: Service {
            var wrapped: any Service
            func run() async throws {
                try await wrapped.run()
            }
        }

        let logger = Logger(label: "swift-otel")
        let resource = OTelResource(configuration: configuration)
        switch configuration.traces.exporter.backing {
        case .otlp:
            switch configuration.traces.otlpExporter.protocol.backing {
            case .grpc:
                #if OTLPGRPC
                let exporter = try OTLPGRPCSpanExporter(configuration: configuration.traces.otlpExporter, logger: logger)
                let processor = OTelBatchSpanProcessor(exporter: exporter, configuration: .init(configuration: configuration.traces.batchSpanProcessor), logger: logger)
                let tracer = OTelTracer(
                    idGenerator: OTelRandomIDGenerator(),
                    sampler: OTelConstantSampler(isOn: true),
                    propagator: OTelW3CPropagator(),
                    processor: processor,
                    environment: .detected(),
                    resource: resource,
                    logger: logger
                )
                return (tracer, TracerWrapper(wrapped: tracer))
                #else // OTLPGRPC
                fatalError("Using the OTLP/GRPC exporter requires the `OTLPGRPC` trait enabled.")
                #endif
            case .httpProtobuf, .httpJSON:
                #if OTLPHTTP
                let exporter = try OTLPHTTPSpanExporter(configuration: configuration.traces.otlpExporter, logger: logger)
                let processor = OTelBatchSpanProcessor(exporter: exporter, configuration: .init(configuration: configuration.traces.batchSpanProcessor), logger: logger)
                let tracer = OTelTracer(
                    idGenerator: OTelRandomIDGenerator(),
                    sampler: OTelConstantSampler(isOn: true),
                    propagator: OTelW3CPropagator(),
                    processor: processor,
                    environment: .detected(),
                    resource: resource,
                    logger: logger
                )
                return (tracer, TracerWrapper(wrapped: tracer))
                #else
                fatalError("Using the OTLP/HTTP + Protobuf exporter requires the `OTLPHTTP` trait enabled.")
                #endif
            }
        case .console, .jaeger, .zipkin:
            fatalError("not implementated")
        }
    }
}

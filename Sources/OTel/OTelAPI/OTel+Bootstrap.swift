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

#if canImport(FoundationEssentials)
import class FoundationEssentials.ProcessInfo
#else
import class Foundation.ProcessInfo
#endif
import Logging
import Metrics
public import ServiceLifecycle
import Tracing

// MARK: - API

extension OTel {
    /// Bootstrap observability backends with OTLP exporters.
    ///
    /// - Parameter configuration: Configuration for observability backends.
    ///
    ///   This value can be used to configure or disable the bootstrapped backends and defaults to
    ///   `OTel.Configuration.default`, which bootstraps all backends with the default configuration defined in the
    ///   OpenTelemetry specification.
    ///
    ///   Configuration can also be provided at runtime with environment variable overrides.
    ///
    /// - Returns: A service that manages the background work for the bootstrapped observability backends.
    ///
    ///   The returned service manages the complete lifecycle of all observability backends. It handles startup,
    ///   background processing, and graceful shutdown of exporters and processors. The service performs these
    ///   operations.
    ///
    ///   > Important: You must run this service in a `ServiceGroup` alongside your application services for
    ///   observability data to be exported.
    ///
    /// This is the primary API for setting up observability in your Swift application. Call this function once during
    /// application startup to configure logging, metrics, and tracing with OTLP exporters.
    ///
    /// This function bootstraps the process-global observability subsystems that are enabled in the configuration.
    /// Attempting to bootstrap these subsystems multiple times will result in a fatal error. If you wish to bootstrap
    /// only a subset of the observability subsystems, provide a configuration with only those subsystems enabled.
    ///
    /// This API supports overriding the configuration using environment variables defined in the OpenTelemetry
    /// specification. This enables operators to customize the observability of your application during deployment.
    /// For more details on the configuration options, their defaults, and their associated environment variables, see
    /// `OTel.Configuration`.
    ///
    /// If you need greater control over the bootstrap of the observability subsystems, use the APIs that return the
    /// backends themselves, for example, `OTel.makeTracingBackend(configuration:)`.
    ///
    /// ## Example usage
    ///
    /// ### Bootstrap observability backends with minimal ceremony
    ///
    /// To bootstrap all the observability backends with default configuration, simply call `OTel.bootstrap` with no
    /// parameters and run the returned service along with your application service.
    ///
    /// ```swift
    /// // Bootstrap observability backends and get a single, opaque service, to run.
    /// let observability = try OTel.bootstrap()
    ///
    /// // Run observability service(s) in a service group with adopter service(s).
    /// let server = MockService(name: "AdopterServer")
    /// let serviceGroup = ServiceGroup(services: [observability, server], logger: .init(label: "ServiceGroup"))
    /// try await serviceGroup.run()
    /// ```
    ///
    /// ### Configure/disable observability backends
    ///
    /// To configure the behavior of the observability backends, first start with the default configuration and override
    /// the properties as required.
    ///
    /// - Note: Some of the values in this example are the default, but are explicitly set for illustrative purposes.
    /// - Note: Additional configuration will be applied from the environment variables defined in the OTel spec.
    ///
    /// ```swift
    /// // Start with defaults.
    /// var config = OTel.Configuration.default
    /// // Configure traces with specific OTLP/gRPC endpoint, with mTLS, compression, and custom timeout.
    /// config.traces.exporter = .otlp
    /// config.traces.otlpExporter.endpoint = "https://otel-collector.example.com:4317"
    /// config.traces.otlpExporter.protocol = .grpc
    /// config.traces.otlpExporter.compression = .gzip
    /// config.traces.otlpExporter.certificateFilePath = "/path/to/cert"
    /// config.traces.otlpExporter.clientCertificateFilePath = "/path/to/cert"
    /// config.traces.otlpExporter.clientKeyFilePath = "/path/to/key"
    /// config.traces.otlpExporter.timeout = .seconds(3)
    /// // Configure metrics with localhost OTLP/HTTP endpoint, without TLS, uncompressed, and different timeout.
    /// config.metrics.exporter = .otlp
    /// config.metrics.otlpExporter.endpoint = "http://localhost:4318"
    /// config.metrics.otlpExporter.protocol = .httpProtobuf
    /// config.metrics.otlpExporter.compression = .none
    /// config.metrics.otlpExporter.timeout = .seconds(5)
    /// // Disable logs entirely.
    /// config.logs.enabled = false
    ///
    /// // Bootstrap observability backends and still get a single, opaque service, to run.
    /// let observability = try OTel.bootstrap(configuration: config)
    ///
    /// // Run observability service(s) in a service group with adopter service(s).
    /// let server = MockService(name: "AdopterServer")
    /// let serviceGroup = ServiceGroup(services: [observability, server], logger: .init(label: "ServiceGroup"))
    /// try await serviceGroup.run()
    /// ```
    public static func bootstrap(configuration: Configuration = .default) throws -> some Service {
        let logger = configuration.makeDiagnosticLogger().withMetadata(component: "bootstrap")
        var configuration = configuration
        configuration.applyEnvironmentOverrides(environment: ProcessInfo.processInfo.environment, logger: logger)

        var services: [Service] = []

        if configuration.logs.enabled {
            try services.append(bootstrapLogs(resolvedConfiguration: configuration, logger: logger))
        }
        if configuration.metrics.enabled {
            try services.append(bootstrapMetrics(resolvedConfiguration: configuration, logger: logger))
        }
        if configuration.traces.enabled {
            try services.append(bootstrapTraces(resolvedConfiguration: configuration, logger: logger))
        }
        if services.isEmpty {
            // If we created a service group that doesn't contain any services, it would return immediately, which would
            // then take down the entire service lifecycle of a server because OTel terminates unexpectedly. To fix
            // this, add a dummy service to the service group that doesn't do anything and just waits for a graceful
            // shutdown.
            struct DummyService: Service {
                func run() async throws {
                    try await gracefulShutdown()
                }
            }
            services.append(DummyService())
        }

        return ServiceGroup(services: services, logger: logger)
    }
}

// MARK: - Internal

extension OTel {
    internal static func bootstrapTraces(resolvedConfiguration: OTel.Configuration, logger: Logger) throws -> some Service {
        let backend = try makeTracingBackend(resolvedConfiguration: resolvedConfiguration, logger: logger)
        logger.info("Bootstrapping instrumentation system with \(resolvedConfiguration.traces.exporterName) exporter.")
        InstrumentationSystem.bootstrap(backend.factory)
        return backend.service
    }

    internal static func bootstrapMetrics(resolvedConfiguration: OTel.Configuration, logger: Logger) throws -> some Service {
        let backend = try makeMetricsBackend(resolvedConfiguration: resolvedConfiguration, logger: logger)
        logger.info("Bootstrapping metrics system with \(resolvedConfiguration.metrics.exporterName) exporter.")
        MetricsSystem.bootstrap(backend.factory)
        return backend.service
    }

    internal static func bootstrapLogs(resolvedConfiguration: OTel.Configuration, logger: Logger) throws -> some Service {
        let backend = try makeLoggingBackend(resolvedConfiguration: resolvedConfiguration, logger: logger)
        if resolvedConfiguration.logs.exporter.backing != .console {
            logger.info(
                """
                Bootstrapping logging system with \(resolvedConfiguration.logs.exporterName) exporter.
                ---
                Only Swift OTel diagnostic logging will use the console logger.

                If you require console logging for local development, use the
                console logs exporter, which can be enabled using the
                following configuration:

                    config.logs.exporter = .console

                Or, run your process with the following environment variable:

                    OTEL_LOGS_EXPORTER=console

                If you require logs to go to both the console and another
                exporter, manually bootstrap the logging subsystem with a
                multiplex log handler. See the documentation of
                `makeLoggingBackend` for details.
                ---
                """
            )
        } else {
            logger.info("Bootstrapping logging system with \(resolvedConfiguration.logs.exporterName) exporter.")
        }
        LoggingSystem.bootstrap(backend.factory)
        return backend.service
    }
}

extension OTel.Configuration.LogsConfiguration {
    fileprivate var exporterName: String {
        switch (exporter.backing, otlpExporter.protocol.backing) {
        case (.none, _): "none"
        case (.console, _): "console"
        case (.otlp, .httpProtobuf): "OTLP/HTTP+Protobuf"
        case (.otlp, .httpJSON): "OTLP/HTTP+json"
        case (.otlp, .grpc): "OTLP/gRPC"
        }
    }
}

extension OTel.Configuration.MetricsConfiguration {
    fileprivate var exporterName: String {
        switch (exporter.backing, otlpExporter.protocol.backing) {
        case (.none, _): "none"
        case (.console, _): "console"
        case (.prometheus, _): "prometheus"
        case (.otlp, .httpProtobuf): "OTLP/HTTP+Protobuf"
        case (.otlp, .httpJSON): "OTLP/HTTP+json"
        case (.otlp, .grpc): "OTLP/gRPC"
        }
    }
}

extension OTel.Configuration.TracesConfiguration {
    fileprivate var exporterName: String {
        switch (exporter.backing, otlpExporter.protocol.backing) {
        case (.none, _): "none"
        case (.console, _): "console"
        case (.jaeger, _): "jaeger"
        case (.zipkin, _): "zipkin"
        case (.otlp, .httpProtobuf): "OTLP/HTTP+Protobuf"
        case (.otlp, .httpJSON): "OTLP/HTTP+json"
        case (.otlp, .grpc): "OTLP/gRPC"
        }
    }
}

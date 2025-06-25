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

import class Foundation.ProcessInfo
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
        try Self.bootstrap(configuration: configuration, environment: ProcessInfo.processInfo.environment)
    }
}

// MARK: - Internal

extension OTel {
    internal static func bootstrap(configuration: Configuration = .default, environment: [String: String]) throws -> some Service {
        var configuration = configuration
        configuration.applyEnvironmentOverrides(environment: environment)

        var services: [Service] = []

        if configuration.logs.enabled {
            try services.append(bootstrapLogs(configuration: configuration))
        }
        if configuration.metrics.enabled {
            try services.append(bootstrapMetrics(configuration: configuration))
        }
        if configuration.traces.enabled {
            try services.append(bootstrapTraces(configuration: configuration))
        }

        return ServiceGroup(services: services, logger: Logger(label: "OTelServiceGroup"))
    }

    internal static func bootstrapTraces(configuration: OTel.Configuration) throws -> some Service {
        let backend = try makeTracingBackend(configuration: configuration)
        InstrumentationSystem.bootstrap(backend.factory)
        return backend.service
    }

    internal static func bootstrapMetrics(configuration: OTel.Configuration) throws -> some Service {
        let backend = try makeMetricsBackend(configuration: configuration)
        MetricsSystem.bootstrap(backend.factory)
        return backend.service
    }

    internal static func bootstrapLogs(configuration: OTel.Configuration) throws -> some Service {
        let backend = try makeLoggingBackend(configuration: configuration)
        LoggingSystem.bootstrap(backend.factory)
        return backend.service
    }
}

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
public import ServiceLifecycle
public import Tracing

/// A service that manages the lifecycle of OpenTelemetry backends and provides access to their factories.
///
/// `OTelService` conforms to ``Service`` and manages the background work for all enabled observability
/// backends (exporters, processors, etc.). It exposes optional factory properties that callers can use
/// to set up process-global or task-local observability without `OTelService` itself touching any globals.
///
/// Use ``OTel/makeBackends(configuration:)`` to create an instance.
///
/// ## Example: Task-local metrics with global logging and tracing
///
/// ```swift
/// let otel = try OTel.makeBackends()
///
/// // Use process-global factories for logging and tracing.
/// if let loggingFactory = otel.loggingFactory {
///     LoggingSystem.bootstrap(loggingFactory)
/// }
/// if let tracer = otel.tracer {
///     InstrumentationSystem.bootstrap(tracer)
/// }
///
/// // Use task-local factory for metrics.
/// let serviceGroup = ServiceGroup(services: [otel, server], logger: logger)
/// try await withMetricsFactory(otel.metricsFactory!) {
///     try await serviceGroup.run()
/// }
/// ```
public struct OTelService: Service {
    /// The logging factory, or `nil` if logging is disabled in the configuration.
    public let loggingFactory: (@Sendable (String) -> any LogHandler)?

    /// The metrics factory, or `nil` if metrics is disabled in the configuration.
    public let metricsFactory: (any MetricsFactory)?

    /// The tracer, or `nil` if tracing is disabled in the configuration.
    public let tracer: (any Tracer)?

    private let serviceGroup: ServiceGroup

    package init(
        loggingFactory: (@Sendable (String) -> any LogHandler)?,
        metricsFactory: (any MetricsFactory)?,
        tracer: (any Tracer)?,
        serviceGroup: ServiceGroup
    ) {
        self.loggingFactory = loggingFactory
        self.metricsFactory = metricsFactory
        self.tracer = tracer
        self.serviceGroup = serviceGroup
    }

    public func run() async throws {
        try await serviceGroup.run()
    }
}

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

public import Logging

extension OTel {
    /// Configuration that controls telemetry collection and export behavior.
    ///
    /// This type provides a centralized place to configure all aspects of the OTLP observability backends,
    /// including service identification, resource attributes, logging, propagation, and signal-specific settings
    /// for traces, metrics, and logs.
    ///
    /// The property names, supported values, and defaults closely follow the OTel specification.
    ///
    /// ### Example usage
    ///
    /// Start with the default configuration and override properties as required.
    ///
    /// > Note: Some values used in the example are the default, and are explicitly set for illustrative purposes.
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
    /// ```
    ///
    /// - Seealso:
    ///   - [](https://opentelemetry.io/docs/languages/sdk-configuration/general)
    ///   - [](https://opentelemetry.io/docs/languages/sdk-configuration/otlp-exporter)
    ///   - [](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables)
    ///   - [](https://opentelemetry.io/docs/specs/otel/protocol/exporter#configuration-options)
    public struct Configuration: Sendable {
        /// The logical name of the service that generates telemetry data.
        ///
        /// The service name appears in trace visualizations and helps you distinguish between different
        /// services in your distributed system.
        ///
        /// - Environment variable(s): `OTEL_SERVICE_NAME`.
        /// - Default value: `unknown_service`.
        /// - Notes: Takes precedence over the `service.name` key in `resourceAttributes`.
        public var serviceName: String

        /// Key-value pairs that describe the entity producing telemetry data.
        ///
        /// Resource attributes provide context about the service, process, host, and other entities
        /// that generate telemetry. Common attributes include service version, deployment environment,
        /// host name, and process ID.
        ///
        /// - Environment variable(s): `OTEL_RESOURCE_ATTRIBUTES` (example: `key1=value1,key2=value2`).
        /// - Default value: Empty dictionary.
        /// - Notes: The `serviceName` property takes precedence over `service.name` in this dictionary.
        public var resourceAttributes: [String: String]

        /// The logger used for internal diagnostic messages.
        ///
        /// This logger is used to record configuration warnings, export failures, and other diagnostic information. It
        /// does not affect application logging or log signal collection.
        ///
        /// - Default value: `.console`.
        public var diagnosticLogger: DiagnosticLoggerSelection

        /// The minimum log level for internal diagnostic messages.
        ///
        /// Controls the verbosity of internal logging. Messages below this level will be filtered out.
        /// This setting only affects diagnostic output, not application log collection.
        ///
        /// - Environment variable(s): `OTEL_LOG_LEVEL`.
        /// - Default value: `.info`.
        public var diagnosticLogLevel: LogLevel

        /// The list of propagators used for context propagation across service boundaries.
        ///
        /// Propagators inject and extract trace context and baggage from carriers (such as HTTP headers)
        /// to maintain trace continuity in distributed systems. Multiple propagators can be configured
        /// to support different propagation formats.
        ///
        /// - Environment variable(s): `OTEL_PROPAGATORS` (example: `tracecontext`).
        /// - Default value: `[.traceContext]` (W3C Trace Context).
        public var propagators: [Propagator]

        /// Configuration for distributed tracing functionality.
        ///
        /// Controls span collection, processing, and export behavior. Traces help you understand
        /// request flow and performance characteristics across distributed services.
        ///
        /// - Default value: `.default` (enabled with default configuration).
        public var traces: TracesConfiguration

        /// Configuration for metrics collection and export.
        ///
        /// Controls metric instrument registration, aggregation, and export behavior. Metrics
        /// provide quantitative measurements of application and system performance.
        ///
        /// - Default value: `.default` (enabled with default configuration).
        public var metrics: MetricsConfiguration

        /// Configuration for structured logging integration.
        ///
        /// Controls log record collection and export behavior. Logs provide detailed event
        /// information and can be correlated with traces for comprehensive observability.
        ///
        /// - Default value: `.default` (enabled with default configuration).
        public var logs: LogsConfiguration

        /// Default configuration.
        ///
        /// See individual property documentation for specific default values, which respect the OTel specification
        /// where possible.
        public static let `default`: Self = .init(
            serviceName: "unknown_service",
            resourceAttributes: [:],
            diagnosticLogger: .console,
            diagnosticLogLevel: .info,
            propagators: [.traceContext],
            traces: .default,
            metrics: .default,
            logs: .default
        )
    }
}

extension OTel.Configuration {
    /// Logger to use for internal diagnostics.
    public struct DiagnosticLoggerSelection: Sendable {
        enum Backing: Sendable {
            case console
            case custom(Logger)
        }

        var backing: Backing

        /// Console logger that logs to standard error.
        public static let console: Self = .init(backing: .console)

        /// Custom logger.
        ///
        /// - Parameter logger: The custom logger to use.
        public static func custom(_ logger: Logger) -> Self { .init(backing: .custom(logger)) }
    }
}

extension OTel.Configuration {
    /// Minimum severity of logging to enable.
    public struct LogLevel: Sendable {
        enum Backing: String, CaseIterable, Sendable {
            case error
            case warning
            case info
            case debug
            case trace
        }

        var backing: Backing

        /// Error log level - only critical errors are logged.
        public static let error: Self = .init(backing: .error)

        /// Warning log level - warnings and errors are logged.
        public static let warning: Self = .init(backing: .warning)

        /// Info log level - informational messages, warnings, and errors are logged.
        public static let info: Self = .init(backing: .info)

        /// Debug log level - all messages including debug information are logged.
        public static let debug: Self = .init(backing: .debug)

        /// Trace log level - all messages including fine-grained debug information are logged.
        public static let trace: Self = .init(backing: .trace)
    }
}

extension OTel.Configuration {
    /// Context propagator for distributed tracing across service boundaries.
    ///
    /// Propagators handle the injection and extraction of trace context and baggage
    /// from carriers such as HTTP headers, enabling trace continuity in distributed systems.
    public struct Propagator: Sendable {
        enum Backing: String, CaseIterable, Sendable {
            case traceContext = "tracecontext"
            case baggage
            case b3
            case b3Multi = "b3multi"
            case jaeger
            case xray
            case otTrace
            case none
        }

        var backing: Backing

        /// W3C Trace Context propagator (recommended).
        public static let traceContext: Self = .init(backing: .traceContext)

        /// W3C Baggage propagator for cross-cutting concerns.
        @available(*, unavailable, message: "This option is not supported by Swift OTel")
        public static let baggage: Self = .init(backing: .baggage)

        /// B3 single header propagator (Zipkin format).
        @available(*, unavailable, message: "This option is not supported by Swift OTel")
        public static let b3: Self = .init(backing: .b3)

        /// B3 multi-header propagator (Zipkin format).
        @available(*, unavailable, message: "This option is not supported by Swift OTel")
        public static let b3Multi: Self = .init(backing: .b3Multi)

        /// Jaeger propagator for Jaeger tracing systems.
        @available(*, unavailable, message: "This option is not supported by Swift OTel")
        public static let jaeger: Self = .init(backing: .jaeger)

        /// AWS X-Ray propagator for AWS environments.
        @available(*, unavailable, message: "This option is not supported by Swift OTel")
        public static let xray: Self = .init(backing: .xray)

        /// OpenTracing propagator for legacy OpenTracing systems.
        @available(*, unavailable, message: "This option is not supported by Swift OTel")
        public static let otTrace: Self = .init(backing: .otTrace)

        /// No-op propagator that performs no context propagation.
        public static let none: Self = .init(backing: .none)
    }
}

extension OTel.Configuration {
    /// Configuration for distributed tracing functionality.
    ///
    /// Controls all aspects of trace collection, processing, and export including span processors,
    /// exporters, and OTLP-specific settings.
    public struct TracesConfiguration: Sendable {
        /// Whether tracing is enabled.
        ///
        /// - Environment variable(s): `OTEL_SDK_DISABLED`.
        /// - Default value: `true`.
        /// - Notes: This value is influenced by a negative boolean, as defined by the OTel spec.
        public var enabled: Bool

        /// This is here to support the `OTEL_SDK_DISABLED` inverted boolean environment variable from the OTel spec.
        internal var disabled: Bool {
            set { enabled = !newValue }
            get { !enabled }
        }

        /// Sampler to be used for traces.
        ///
        /// - Environment variable(s): `OTEL_TRACES_SAMPLER`, `OTEL_TRACES_SAMPLER_ARG`.
        /// - Default value: `.parentBasedAlwaysOn`.
        public var sampler: SamplerConfiguration

        /// Configuration for the batch span processor.
        ///
        /// - Default value: `.default`.
        public var batchSpanProcessor: BatchSpanProcessorConfiguration

        /// Selection of trace exporter implementation.
        ///
        /// - Environment variable(s): `OTEL_TRACES_EXPORTER`.
        /// - Default value: `.otlp`.
        public var exporter: ExporterSelection

        /// Configuration for OTLP trace export when using the OTLP exporter.
        ///
        /// - Default value: `.default`.
        public var otlpExporter: OTLPExporterConfiguration

        /// Default traces configuration.
        ///
        /// See individual property documentation for specific default values, which respect the OTel specification
        /// where possible.
        @_documentation(visibility: internal)
        public static let `default`: Self = .init(
            enabled: true,
            sampler: .parentBasedAlwaysOn,
            batchSpanProcessor: .default,
            exporter: .otlp,
            otlpExporter: .default
        )
    }

    /// Configuration for metrics collection and export.
    ///
    /// Controls metric instrument registration, aggregation, and periodic export behavior.
    public struct MetricsConfiguration: Sendable {
        /// Whether metrics collection is enabled.
        ///
        /// - Environment variable(s): `OTEL_SDK_DISABLED`.
        /// - Default value: `true`.
        /// - Notes: This value is influenced by a negative boolean, as defined by the OTel spec.
        public var enabled: Bool

        /// This is here to support the `OTEL_SDK_DISABLED` inverted boolean environment variable from the OTel spec.
        internal var disabled: Bool {
            set { enabled = !newValue }
            get { !enabled }
        }

        /// Interval between metric export attempts.
        ///
        /// - Environment variable(s): `OTEL_METRIC_EXPORT_INTERVAL`.
        /// - Default value: 60 seconds.
        public var exportInterval: Duration

        /// Maximum time to wait for each export operation.
        ///
        /// - Environment variable(s): `OTEL_METRIC_EXPORT_TIMEOUT`.
        /// - Default value: 30 seconds.
        public var exportTimeout: Duration

        /// The default bucket upper bounds for duration histograms created for a Swift Metrics `Timer`.
        ///
        /// - Environment variable(s): `OTEL_SWIFT_METRICS_DEFAULT_DURATION_HISTOGRAM_BUCKETS`.
        /// - Default value: `[0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10000].map(Duration.milliseconds)`.
        /// - Notes: Buckets from `-∞` and  to `+∞` are derived, e.g. `[0, 5]` implies `(-∞, 0]`, `(0, 5]`, and `(5, +∞)`.
        public var defaultDurationHistogramBuckets: [Duration]

        /// The bucket upper bounds for duration histograms created for a Swift Metrics `Timer` with a specific label.
        ///
        /// - Environment variable(s): None.
        /// - Default value: `[:]`.
        public var durationHistogramBuckets: [String: [Duration]]

        /// The default bucket upper bounds for value histograms created for a Swift Metrics `Recorder`.
        ///
        /// - Environment variable(s): `OTEL_SWIFT_METRICS_DEFAULT_VALUE_HISTOGRAM_BUCKETS`.
        /// - Default value: `[0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10000]`
        /// - Notes: Buckets from `-∞` and  to `+∞` are derived, e.g. `[0, 5]` implies `(-∞, 0]`, `(0, 5]`, and `(5, +∞)`.
        public var defaultValueHistogramBuckets: [Double]

        /// The bucket upper bounds for value histograms created for a Swift Metrics `Recorder` with a specific label.
        ///
        /// - Environment variable(s): None.
        /// - Default value: `[:]`.
        public var valueHistogramBuckets: [String: [Double]]

        /// Selection of metrics exporter implementation.
        ///
        /// - Environment variable(s): `OTEL_METRICS_EXPORTER`.
        /// - Default value: `.otlp`.
        public var exporter: ExporterSelection

        /// Configuration for OTLP metrics export when using the OTLP exporter.
        ///
        /// - Default value: `.default`.
        public var otlpExporter: OTLPExporterConfiguration

        /// Default logs configuration.
        ///
        /// See individual property documentation for specific default values, which respect the OTel specification
        /// where possible.
        @_documentation(visibility: internal)
        public static let `default`: Self = .init(
            enabled: true,
            exportInterval: .seconds(60),
            exportTimeout: .seconds(30),
            defaultDurationHistogramBuckets: defaultHistogramBuckets.map(Duration.milliseconds),
            durationHistogramBuckets: [:],
            defaultValueHistogramBuckets: defaultHistogramBuckets,
            valueHistogramBuckets: [:],
            exporter: .otlp,
            otlpExporter: .default
        )

        static let defaultHistogramBuckets = [
            0.0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10000,
        ]
    }

    /// Configuration for structured logging integration.
    ///
    /// Controls log record collection and export behavior for application logs that are
    /// integrated with OpenTelemetry observability.
    public struct LogsConfiguration: Sendable {
        /// Whether log signal collection is enabled.
        ///
        /// - Environment variable(s): `OTEL_SDK_DISABLED`.
        /// - Default value: `true`.
        /// - Notes: This value is influenced by a negative boolean, as defined by the OTel spec.
        public var enabled: Bool

        /// This is here to support the `OTEL_SDK_DISABLED` inverted boolean environment variable from the OTel spec.
        internal var disabled: Bool {
            set { enabled = !newValue }
            get { !enabled }
        }

        /// Default log level for loggers returned by the logging backend factory.
        ///
        /// - Environment variable(s): `OTEL_SWIFT_LOG_LEVEL` (SDK-specific)
        /// - Default value: `.info`
        public var level: LogLevel

        /// Configuration for the batch log record processor.
        ///
        /// - Default value: `.default`.
        public var batchLogRecordProcessor: BatchLogRecordProcessorConfiguration

        /// Selection of logs exporter implementation.
        ///
        /// - Environment variable(s): `OTEL_LOGS_EXPORTER`.
        /// - Default value: `.otlp`.
        public var exporter: ExporterSelection

        /// Configuration for OTLP logs export when using the OTLP exporter.
        ///
        /// - Default value: `.default`.
        public var otlpExporter: OTLPExporterConfiguration

        /// Default configuration.
        ///
        /// See individual property documentation for specific default values, which respect the OTel specification
        /// where possible.
        @_documentation(visibility: internal)
        public static let `default`: Self = .init(
            enabled: true,
            level: .info,
            batchLogRecordProcessor: .default,
            exporter: .otlp,
            otlpExporter: .default
        )
    }
}

extension OTel.Configuration.TracesConfiguration {
    /// Selection of traces sampler.
    public struct SamplerConfiguration: Sendable {
        enum Backing: String, CaseIterable, Sendable {
            case alwaysOn = "always_on"
            case alwaysOff = "always_off"
            case traceIDRatio = "traceidratio"
            case parentBasedAlwaysOn = "parentbased_always_on"
            case parentBasedAlwaysOff = "parentbased_always_off"
            case parentBasedTraceIDRatio = "parentbased_traceidratio"
            case parentBasedJaegerRemote = "parentbased_jaeger_remote"
            case jaegerRemote = "jaeger_remote"
            case xray
        }

        enum ArgumentBacking: Equatable, Sendable {
            case traceIDRatio(samplingProbability: Double)
            case jaegerRemote(endpoint: String, pollingInterval: Duration, initialSamplingRate: Double)
        }

        var backing: Backing

        var argument: ArgumentBacking?

        /// A sampler that always records the span.
        public static let alwaysOn: Self = .init(backing: .alwaysOn)

        /// A sampler that always drops the span.
        public static let alwaysOff: Self = .init(backing: .alwaysOff)

        /// A sampler that records a span based on ratio-based probability.
        public static func traceIDRatio(ratio: Double) -> Self? {
            guard ratio >= 0.0, ratio <= 1.0 else { return nil }
            return Self(backing: .traceIDRatio, argument: .traceIDRatio(samplingProbability: ratio))
        }

        /// A sampler that records a span based on ratio-based probability.
        public static var traceIDRatio: Self { .traceIDRatio(ratio: 1.0)! }

        /// Inherits parent span's sampling decision; samples all root spans.
        public static let parentBasedAlwaysOn: Self = .init(backing: .parentBasedAlwaysOn)

        /// Inherits parent span's sampling decision; never samples root spans.
        public static let parentBasedAlwaysOff: Self = .init(backing: .parentBasedAlwaysOff)

        /// Inherits parent span's sampling decision; samples root spans by trace ID ratio.
        public static func parentBasedTraceIDRatio(ratio: Double) -> Self? {
            guard ratio >= 0.0, ratio <= 1.0 else { return nil }
            return Self(backing: .parentBasedTraceIDRatio, argument: .traceIDRatio(samplingProbability: ratio))
        }

        /// Inherits parent span's sampling decision; samples root spans by trace ID ratio.
        public static var parentBasedTraceIDRatio: Self { .parentBasedTraceIDRatio(ratio: 1.0)! }

        /// Inherits parent span's sampling decision; uses Jaeger remote sampling for root spans.
        @available(*, unavailable, message: "This option is not supported by Swift OTel")
        public static let parentBasedJaegerRemote: Self = .init(backing: .parentBasedJaegerRemote)

        /// Uses Jaeger agent's remote sampling configuration for all spans.
        @available(*, unavailable, message: "This option is not supported by Swift OTel")
        public static let jaegerRemote: Self = .init(backing: .jaegerRemote)

        /// Uses AWS X-Ray's centralized sampling rules and decisions.
        @available(*, unavailable, message: "This option is not supported by Swift OTel")
        public static let xray: Self = .init(backing: .xray)
    }
}

extension OTel.Configuration.TracesConfiguration {
    /// Configuration for the batch span processor.
    ///
    /// The batch processor collects spans in memory and exports them in batches to improve
    /// performance and reduce network overhead.
    public struct BatchSpanProcessorConfiguration: Sendable {
        /// Maximum time to wait before triggering an export.
        ///
        /// - Environment variable(s): `OTEL_BSP_SCHEDULE_DELAY`.
        /// - Default value: 5 seconds.
        public var scheduleDelay: Duration

        /// Maximum time to wait for each export operation.
        ///
        /// - Environment variable(s): `OTEL_BSP_EXPORT_TIMEOUT`.
        /// - Default value: 30 seconds.
        public var exportTimeout: Duration

        /// Maximum number of spans to keep in the queue.
        ///
        /// After the size is reached spans are dropped.
        ///
        /// - Environment variable(s): `OTEL_BSP_MAX_QUEUE_SIZE`.
        /// - Default value: 2048.
        public var maxQueueSize: Int

        /// Maximum number of spans to export in a single batch.
        ///
        /// - Environment variable(s): `OTEL_BSP_MAX_EXPORT_BATCH_SIZE`.
        /// - Default value: 512.
        public var maxExportBatchSize: Int

        /// Default batch span processor configuration.
        ///
        /// See individual property documentation for specific default values, which respect the OTel specification
        /// where possible.
        @_documentation(visibility: internal)
        public static let `default`: Self = .init(
            scheduleDelay: .seconds(5),
            exportTimeout: .seconds(30),
            maxQueueSize: 2048,
            maxExportBatchSize: 512
        )
    }
}

extension OTel.Configuration.TracesConfiguration {
    /// Selection of trace exporter implementation.
    ///
    /// Determines how completed spans are exported from the application to observability backends.
    public struct ExporterSelection: Sendable {
        enum Backing: String, CaseIterable, Sendable {
            case otlp
            case jaeger
            case zipkin
            case console
            case none
        }

        var backing: Backing

        /// OTLP (OpenTelemetry Protocol) exporter for traces.
        public static let otlp: Self = .init(backing: .otlp)

        /// No automatically configured exporter for traces.
        public static let none: Self = .init(backing: .none)

        /// Jaeger exporter for traces.
        @available(*, unavailable, message: "This option is not supported by Swift OTel")
        public static let jaeger: Self = .init(backing: .jaeger)

        /// Zipkin exporter for traces.
        @available(*, unavailable, message: "This option is not supported by Swift OTel")
        public static let zipkin: Self = .init(backing: .zipkin)

        /// Console exporter for traces (development/debugging).
        @available(*, unavailable, message: "This option is not supported by Swift OTel")
        public static let console: Self = .init(backing: .console)
    }
}

extension OTel.Configuration.MetricsConfiguration {
    /// Selection of metrics exporter implementation.
    ///
    /// Determines how collected metrics are exported from the application to observability backends.
    public struct ExporterSelection: Sendable {
        enum Backing: String, CaseIterable, Sendable {
            case otlp
            case prometheus
            case console
            case none
        }

        var backing: Backing

        /// OTLP (OpenTelemetry Protocol) exporter for metrics.
        public static let otlp: Self = .init(backing: .otlp)

        /// No automatically configured exporter for metrics.
        public static let none: Self = .init(backing: .none)

        /// Prometheus exporter for metrics.
        @available(*, unavailable, message: "This option is not supported by Swift OTel")
        public static let prometheus: Self = .init(backing: .prometheus)

        /// Console exporter for metrics (development/debugging).
        @available(*, unavailable, message: "This option is not supported by Swift OTel")
        public static let console: Self = .init(backing: .console)
    }
}

extension OTel.Configuration.LogsConfiguration {
    /// Selection of logs exporter implementation.
    ///
    /// Determines how log records are exported from the application to observability backends.
    public struct ExporterSelection: Sendable {
        enum Backing: String, CaseIterable, Sendable {
            case otlp
            case console
            case none
        }

        var backing: Backing

        /// OTLP (OpenTelemetry Protocol) exporter for logs.
        public static let otlp: Self = .init(backing: .otlp)

        /// No automatically configured exporter for logs.
        public static let none: Self = .init(backing: .none)

        /// Console exporter for logs (development/debugging).
        public static let console: Self = .init(backing: .console)
    }
}

extension OTel.Configuration.LogsConfiguration {
    /// Configuration for the batch log record processor.
    ///
    /// The batch processor collects log records in memory and exports them in batches to improve
    /// performance and reduce network overhead.
    public struct BatchLogRecordProcessorConfiguration: Sendable {
        /// Maximum time to wait before triggering an export.
        ///
        /// - Environment variable(s): `OTEL_BLRP_SCHEDULE_DELAY`.
        /// - Default value: 1 second.
        public var scheduleDelay: Duration

        /// Maximum time to wait for each export operation.
        ///
        /// - Environment variable(s): `OTEL_BLRP_EXPORT_TIMEOUT`.
        /// - Default value: 30 seconds.
        public var exportTimeout: Duration

        /// Maximum number of log records to keep in the queue.
        ///
        /// After the size is reached logs are dropped.
        ///
        /// - Environment variable(s): `OTEL_BLRP_MAX_QUEUE_SIZE`.
        /// - Default value: 2048.
        public var maxQueueSize: Int

        /// Maximum number of log records to export in a single batch.
        ///
        /// - Environment variable(s): `OTEL_BLRP_MAX_EXPORT_BATCH_SIZE`.
        /// - Default value: 512.
        public var maxExportBatchSize: Int

        /// Default batch span processor configuration.
        ///
        /// See individual property documentation for specific default values, which respect the OTel specification
        /// where possible.
        @_documentation(visibility: internal)
        public static let `default`: Self = .init(
            scheduleDelay: .seconds(1),
            exportTimeout: .seconds(30),
            maxQueueSize: 2048,
            maxExportBatchSize: 512
        )
    }
}

extension OTel.Configuration {
    /// Configuration for OTLP (OpenTelemetry Protocol) exporters.
    ///
    /// Controls connection details, security settings, and transport options for exporting
    /// telemetry data using the OpenTelemetry Protocol. This configuration supports both
    /// HTTP and gRPC transport protocols with comprehensive security and customization options.
    ///
    /// Signal-specific environment variables take precedence over general ones, allowing
    /// fine-grained control over traces, metrics, and logs export behavior.
    public struct OTLPExporterConfiguration: Sendable {
        /// Target URL to which the exporter sends spans, metrics, or logs.
        ///
        /// The endpoint URL specifies where telemetry data should be sent.
        ///
        /// - Environment variable(s):
        ///   - `OTEL_EXPORTER_OTLP_ENDPOINT`
        ///   - `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`
        ///   - `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`
        ///   - `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT`
        /// - Default values:
        ///   - `http://localhost:4317` (for OTLP/gRPC)
        ///   - `http://localhost:4318` (for OTLP/HTTP)
        /// - Notes: Signal-specific configuration takes precedence over the general configuration.
        ///
        /// - Important: The endpoint MUST include a scheme, which MUST be either `http` or `https`. TLS is only used
        ///              when the scheme is `https`.
        ///
        /// - Important: When used with OTLP/HTTP, the _default_ endpoint is appended with a signal-specific path:
        ///   - Traces: `/v1/traces` → `http://localhost:4318/v1/traces`
        ///   - Metrics: `/v1/metrics` → `http://localhost:4318/v1/metrics`
        ///   - Logs: `/v1/logs` → `http://localhost:4318/v1/logs`
        ///
        ///   But if you manually set this parameter after construction, the new value will be used _as-is_.
        public var endpoint: String { didSet { endpointHasBeenExplicitlySet = true } }

        /// For OTLP/HTTP, how the endpoint is derived depends on whether the shared and/or specific keys are set.
        ///
        /// > Based on the environment variables above, the OTLP/HTTP exporter MUST construct URLs for each
        /// > signal as follow:
        /// >
        /// > 1. For the per-signal variables (`OTEL_EXPORTER_OTLP_<signal>_ENDPOINT`), the URL MUST be usedas-is
        /// >    without any modification. The only exception is that if an URL contains no path part, the root
        /// >    path `/` MUST be used (see Example 2).
        /// > 2. If signals are sent that have no per-signal configuration from the previous point,
        /// >    `OTEL_EXPORTER_OTLP_ENDPOINT` is used as a base URL and the signals are sent to these paths
        /// >    relative to that:
        /// >    - Traces: `v1/traces`
        /// >    - Metrics: `v1/metrics`
        /// >    - Logs: `v1/logs`
        /// >    Non-normatively, this could be implemented by ensuring that the base URL ends with a slash and
        /// >    then appending the relative URLs as strings.
        /// >
        /// > An SDK MUST NOT modify the URL in ways other than specified above. That also means, if the port is
        /// > empty or not given, TCP port 80 is the default for the http scheme and TCP port 443 is the default
        /// > for the https scheme, as per the usual rules for these schemes (RFC 7230).
        /// > — source: https://opentelemetry.io/docs/specs/otel/protocol/exporter/#endpoint-urls-for-otlphttp
        ///
        /// As per the spec, we defer this responsibility to the OTLP/HTTP exporters.
        ///
        /// However, to make a clearer configuration for our API users, we already have per-signal OTLP exporter
        /// configuration, and to allow the exporters the ability to follow this policy, the exporter must be able
        /// to tell if the value is default, or explicitly set, either in-code or by an environment override.
        internal var endpointHasBeenExplicitlySet: Bool = false

        var logsHTTPEndpoint: String {
            switch (endpointHasBeenExplicitlySet, endpoint.hasSuffix("/")) {
            case (true, _): endpoint
            case (false, true): "\(endpoint)v1/logs"
            case (false, false): "\(endpoint)/v1/logs"
            }
        }

        var metricsHTTPEndpoint: String {
            switch (endpointHasBeenExplicitlySet, endpoint.hasSuffix("/")) {
            case (true, _): endpoint
            case (false, true): "\(endpoint)v1/metrics"
            case (false, false): "\(endpoint)/v1/metrics"
            }
        }

        var tracesHTTPEndpoint: String {
            switch (endpointHasBeenExplicitlySet, endpoint.hasSuffix("/")) {
            case (true, _): endpoint
            case (false, true): "\(endpoint)v1/traces"
            case (false, false): "\(endpoint)/v1/traces"
            }
        }

        var grpcEndpoint: String {
            endpointHasBeenExplicitlySet ? endpoint : "http://localhost:4317"
        }

        /// Path to certificate for verifying server's TLS credentials.
        ///
        /// When not specified, the system's default certificate store is used.
        ///
        /// - Environment variable(s):
        ///   - `OTEL_EXPORTER_OTLP_CERTIFICATE`
        ///   - `OTEL_EXPORTER_OTLP_TRACES_CERTIFICATE`
        ///   - `OTEL_EXPORTER_OTLP_METRICS_CERTIFICATE`
        ///   - `OTEL_EXPORTER_OTLP_LOGS_CERTIFICATE`
        /// - Default value: `nil`
        /// - Notes: Signal-specific configuration takes precedence over the general configuration.
        public var certificateFilePath: String?

        /// Path to the client private key for mTLS communication, in PEM format.
        ///
        /// Must be provided together with the client certificate for mTLS to work.
        ///
        /// - Environment variable(s):
        ///   - `OTEL_EXPORTER_OTLP_CLIENT_KEY`
        ///   - `OTEL_EXPORTER_OTLP_TRACES_CLIENT_KEY`
        ///   - `OTEL_EXPORTER_OTLP_METRICS_CLIENT_KEY`
        ///   - `OTEL_EXPORTER_OTLP_LOGS_CLIENT_KEY`
        /// - Default value: `nil`
        /// - Note: Signal-specific configuration takes precedence over the general configuration.
        public var clientKeyFilePath: String?

        /// Path to client certificate/chain trust for mTLS communication, in PEM format.
        ///
        /// Must be provided together with the client private key for mTLS to work.
        ///
        /// - Environment variable(s):
        ///   - `OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE`
        ///   - `OTEL_EXPORTER_OTLP_TRACES_CLIENT_CERTIFICATE`
        ///   - `OTEL_EXPORTER_OTLP_METRICS_CLIENT_CERTIFICATE`
        ///   - `OTEL_EXPORTER_OTLP_LOGS_CLIENT_CERTIFICATE`
        /// - Default value: `nil`
        /// - Notes: Signal-specific configuration takes precedence over the general configuration.
        public var clientCertificateFilePath: String?

        /// Key-value pairs used as headers for gRPC or HTTP requests.
        ///
        /// Additional HTTP headers to include in export requests. Headers are specified
        /// as key-value pairs and can be used for authentication, routing, or other purposes.
        ///
        /// - Environment variable(s):
        ///   - `OTEL_EXPORTER_OTLP_HEADERS`
        ///   - `OTEL_EXPORTER_OTLP_TRACES_HEADERS`
        ///   - `OTEL_EXPORTER_OTLP_METRICS_HEADERS`
        ///   - `OTEL_EXPORTER_OTLP_LOGS_HEADERS`
        /// - Default value: Empty array
        /// - Format: W3C Baggage format: `key1=value1,key2=value2`
        /// - Notes: Signal-specific configuration takes precedence over the general configuration.
        public var headers: [(String, String)]

        /// Compression method for request payload.
        ///
        /// Controls whether and how telemetry data is compressed before transmission to reduce
        /// network bandwidth usage. Supported compression algorithms vary by transport protocol.
        ///
        /// - Environment variable(s):
        ///   - `OTEL_EXPORTER_OTLP_COMPRESSION`
        ///   - `OTEL_EXPORTER_OTLP_TRACES_COMPRESSION`
        ///   - `OTEL_EXPORTER_OTLP_METRICS_COMPRESSION`
        ///   - `OTEL_EXPORTER_OTLP_LOGS_COMPRESSION`
        /// - Default value: `.none`
        /// - Supported values: `none`, `gzip`
        /// - Notes: Signal-specific configuration takes precedence over the general configuration.
        public var compression: Compression

        /// Maximum time the exporter waits for each batch export.
        ///
        /// Specifies the maximum duration to wait for export operations to complete.
        /// If an export operation takes longer than this timeout, it will be cancelled.
        ///
        /// - Environment variable(s):
        ///   - `OTEL_EXPORTER_OTLP_TIMEOUT`
        ///   - `OTEL_EXPORTER_OTLP_TRACES_TIMEOUT`
        ///   - `OTEL_EXPORTER_OTLP_METRICS_TIMEOUT`
        ///   - `OTEL_EXPORTER_OTLP_LOGS_TIMEOUT`
        /// - Default value: 10 seconds.
        /// - Notes: Signal-specific configuration takes precedence over the general configuration.
        public var timeout: Duration

        /// The transport protocol for OTLP communication.
        ///
        /// Determines the wire format and transport mechanism used for exporting telemetry data
        /// via the OpenTelemetry Protocol. Different protocols may have different performance
        /// characteristics and compatibility requirements.
        ///
        /// - Environment variable(s):
        ///   - `OTEL_EXPORTER_OTLP_PROTOCOL`
        ///   - `OTEL_EXPORTER_OTLP_TRACES_PROTOCOL`
        ///   - `OTEL_EXPORTER_OTLP_METRICS_PROTOCOL`
        ///   - `OTEL_EXPORTER_OTLP_LOGS_PROTOCOL`
        /// - Default value: `http/protobuf`
        /// - Supported values: `grpc`, `http/protobuf`, `http/json`
        /// - Notes: Signal-specific configuration takes precedence over the general configuration.
        public var `protocol`: Protocol

        /// Default OTLP exporter configuration.
        ///
        /// See individual property documentation for specific default values, which respect the OTel specification
        /// where possible.
        @_documentation(visibility: internal)
        public static let `default`: Self = .init(
            endpoint: "http://localhost:4318",
            certificateFilePath: nil,
            clientKeyFilePath: nil,
            clientCertificateFilePath: nil,
            headers: [],
            compression: .none,
            timeout: .seconds(10),
            protocol: .init(backing: .httpProtobuf)
        )
    }
}

extension OTel.Configuration.OTLPExporterConfiguration {
    /// Compression algorithm for OTLP export payloads.
    ///
    /// Controls whether and how telemetry data is compressed before transmission to reduce
    /// network bandwidth usage.
    public struct Compression: Sendable {
        enum Backing: String, CaseIterable {
            case gzip
            case none
        }

        var backing: Backing

        /// No compression applied to export payloads.
        public static let none: Self = .init(backing: .none)

        /// GZIP compression applied to export payloads.
        public static let gzip: Self = .init(backing: .gzip)
    }

    /// OTLP transport protocol specification.
    ///
    /// Determines the wire format and transport mechanism used for exporting telemetry data
    /// via the OpenTelemetry Protocol.
    // swiftformat:disable:next redundantBackticks
    public struct `Protocol`: Equatable, Sendable {
        enum Backing: String, CaseIterable {
            case grpc
            case httpProtobuf = "http/protobuf"
            case httpJSON = "http/json"
        }

        var backing: Backing

        /// gRPC transport protocol for OTLP.
        #if !OTLPGRPC
        @available(*, unavailable, message: "Using the OTLP/gRPC exporter requires the `OTLPGRPC` trait enabled.")
        #endif
        @available(gRPCSwift, *)
        public static let grpc: Self = .init(backing: .grpc)

        /// HTTP transport with Protocol Buffers encoding for OTLP.
        #if !OTLPHTTP
        @available(*, unavailable, message: "Using the OTLP/HTTP exporter requires the `OTLPHTTP` trait enabled.")
        #endif
        public static let httpProtobuf: Self = .init(backing: .httpProtobuf)

        /// HTTP transport with JSON encoding for OTLP.
        #if !OTLPHTTP
        @available(*, unavailable, message: "Using the OTLP/HTTP exporter requires the `OTLPHTTP` trait enabled.")
        #endif
        public static let httpJSON: Self = .init(backing: .httpJSON)
    }
}

extension OTel.Configuration {
    /// Configuration for the batch logging metadata provider.
    /// - TODO: should this be a property of the Configuratino struct?
    public struct LoggingMetadataProviderConfiguration: Sendable {
        /// Logging metadata key used to record the trace ID.
        ///
        /// - Default value: `"trace_id"`
        public var traceIDKey: String

        /// Logging metadata key used to record the span ID.
        ///
        /// - Default value: `"span_id"`
        public var spanIDKey: String

        /// Logging metadata key used to record the trace flags.
        ///
        /// - Default value: `"trace_flags"`
        public var traceFlagsKey: String

        /// Default logging metadata provider configuration.
        ///
        /// See individual property documentation for specific default values.
        public static let `default`: Self = .init(
            traceIDKey: "trace_id",
            spanIDKey: "span_id",
            traceFlagsKey: "trace_flags"
        )
    }
}

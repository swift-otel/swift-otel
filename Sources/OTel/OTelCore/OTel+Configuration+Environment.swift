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

extension OTel.Configuration {
    /// An environment variable key used to lookup OTel configuration overrides.
    internal enum Key {
        internal enum Signal { case traces, metrics, logs }
        /// A key for an option configured using a single key.
        ///
        case single(OTel.Configuration.Key.GeneralKey)

        /// A key for an option configured with a singal-specific key, and a shared fallback key.
        case signalSpecific(OTel.Configuration.Key.SignalSpecificKey, Signal)

        struct GeneralKey {
            var key: String
        }

        struct SignalSpecificKey {
            var shared: String
            var traces: String
            var metrics: String
            var logs: String
        }

        var environmentVariableName: String {
            switch self {
            case .single(let generalKey):
                generalKey.key
            case .signalSpecific(let signalSpecificKey, let signal):
                switch signal {
                case .logs: signalSpecificKey.logs
                case .metrics: signalSpecificKey.metrics
                case .traces: signalSpecificKey.traces
                }
            }
        }
    }
}

extension OTel.Configuration.Key.GeneralKey {
    static let sdkDisabled = Self(key: "OTEL_SDK_DISABLED")
    static let resourceAttributes = Self(key: "OTEL_RESOURCE_ATTRIBUTES")
    static let serviceName = Self(key: "OTEL_SERVICE_NAME")
    static let logLevel = Self(key: "OTEL_LOG_LEVEL")
    static let tracesExporter = Self(key: "OTEL_TRACES_EXPORTER")
    static let metricsExporter = Self(key: "OTEL_METRICS_EXPORTER")
    static let metricExportInterval = Self(key: "OTEL_METRIC_EXPORT_INTERVAL")
    static let metricExportTimeout = Self(key: "OTEL_METRIC_EXPORT_TIMEOUT")
    static let metricDefaultValueHistogramBuckets = Self(key: "OTEL_SWIFT_METRICS_DEFAULT_VALUE_HISTOGRAM_BUCKETS")
    static let metricDefaultDurationHistogramBuckets = Self(key: "OTEL_SWIFT_METRICS_DEFAULT_DURATION_HISTOGRAM_BUCKETS")
    static let logsExporter = Self(key: "OTEL_LOGS_EXPORTER")
    static let logsLevel = Self(key: "OTEL_SWIFT_LOG_LEVEL") // SDK-specific => different format.
    static let propagators = Self(key: "OTEL_PROPAGATORS")
    static let sampler = Self(key: "OTEL_TRACES_SAMPLER")
    static let samplerArgument = Self(key: "OTEL_TRACES_SAMPLER_ARG")
    static let batchSpanProcessorScheduleDelay = Self(key: "OTEL_BSP_SCHEDULE_DELAY")
    static let batchSpanProcessorExportTimeout = Self(key: "OTEL_BSP_EXPORT_TIMEOUT")
    static let batchSpanProcessorMaxQueueSize = Self(key: "OTEL_BSP_MAX_QUEUE_SIZE")
    static let batchSpanProcessorExportBatchSize = Self(key: "OTEL_BSP_MAX_EXPORT_BATCH_SIZE")
    static let batchLogRecordProcessorScheduleDelay = Self(key: "OTEL_BLRP_SCHEDULE_DELAY")
    static let batchLogRecordProcessorExportTimeout = Self(key: "OTEL_BLRP_EXPORT_TIMEOUT")
    static let batchLogRecordProcessorMaxQueueSize = Self(key: "OTEL_BLRP_MAX_QUEUE_SIZE")
    static let batchLogRecordProcessorExportBatchSize = Self(key: "OTEL_BLRP_MAX_EXPORT_BATCH_SIZE")
}

extension OTel.Configuration.Key.SignalSpecificKey {
    private static func otlpExporterKey(suffix: String) -> Self {
        Self(
            shared: "OTEL_EXPORTER_OTLP_\(suffix)",
            traces: "OTEL_EXPORTER_OTLP_TRACES_\(suffix)",
            metrics: "OTEL_EXPORTER_OTLP_METRICS_\(suffix)",
            logs: "OTEL_EXPORTER_OTLP_LOGS_\(suffix)"
        )
    }

    static let otlpExporterEndpoint = Self.otlpExporterKey(suffix: "ENDPOINT")
    static let otlpExporterInsecure = Self.otlpExporterKey(suffix: "INSECURE")
    static let otlpExporterCertificate = Self.otlpExporterKey(suffix: "CERTIFICATE")
    static let otlpExporterClientKey = Self.otlpExporterKey(suffix: "CLIENT_KEY")
    static let otlpExporterClientCertificate = Self.otlpExporterKey(suffix: "CLIENT_CERTIFICATE")
    static let otlpExporterHeaders = Self.otlpExporterKey(suffix: "HEADERS")
    static let otlpExporterCompression = Self.otlpExporterKey(suffix: "COMPRESSION")
    static let otlpExporterTimeout = Self.otlpExporterKey(suffix: "TIMEOUT")
    static let otlpExporterProtocol = Self.otlpExporterKey(suffix: "PROTOCOL")
}

extension [String: String] {
    func getStringValue(_ lookup: OTel.Configuration.Key) -> String? {
        switch lookup {
        case .single(let generalKey):
            getStringValue(generalKey)
        case .signalSpecific(let signalSpecificKey, let signal):
            getStringValue(signalSpecificKey, signal: signal)
        }
    }

    func getStringValue(_ key: OTel.Configuration.Key.GeneralKey) -> String? {
        self[key.key]
    }

    func getStringValue(_ key: OTel.Configuration.Key.SignalSpecificKey, signal: OTel.Configuration.Key.Signal) -> String? {
        switch signal {
        case .traces: self[key.traces] ?? self[key.shared]
        case .metrics: self[key.metrics] ?? self[key.shared]
        case .logs: self[key.logs] ?? self[key.shared]
        }
    }
}

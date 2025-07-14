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
    static let logsExporter = Self(key: "OTEL_LOGS_EXPORTER")
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
            self.getStringValue(generalKey)
        case .signalSpecific(let signalSpecificKey, let signal):
            self.getStringValue(signalSpecificKey, signal: signal)
        }
    }

    func getBoolValue(_ key: OTel.Configuration.Key) -> Bool? {
        // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#boolean
        getStringValue(key)?.lowercased() == "true"
    }

    func getIntegerValue(_ key: OTel.Configuration.Key) -> Int? {
        // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#integer
        guard let value = getStringValue(key).flatMap(Int.init), value >= 0 else {
            return nil
        }
        return value
    }

    func getDurationValue(_ key: OTel.Configuration.Key) -> Duration? {
        // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#duration
        guard let value = getIntegerValue(key) else {
            return nil
        }
        return .milliseconds(value)
    }

    func getTimeoutValue(_ key: OTel.Configuration.Key) -> Duration? {
        // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#timeout
        let value = getDurationValue(key)
        if value == .zero {
            return .seconds(Int.max)
        }
        return value
    }

    func getHeadersValue(_ key: OTel.Configuration.Key) -> [(String, String)]? {
        // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#specifying-headers-via-environment-variables
        guard let value = getStringValue(key) else { return nil }
        let headers = value.utf8.split(separator: .init(ascii: ","))
        return headers.compactMap { header in
            let pair = header.split(separator: .init(ascii: "="), maxSplits: 1, omittingEmptySubsequences: true)
            guard let key = pair.first, let value = pair.dropFirst().first else { return nil }
            return (
                String(decoding: key, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines),
                String(decoding: value, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    func getEnumValue<E: RawRepresentable<String>>(of type: E.Type = E.self, _ key: OTel.Configuration.Key) -> E? {
        guard let rawValue = getStringValue(key) else { return nil }
        return E(rawValue: rawValue)
    }
}

/// Overloads for general and signal-specific keys to simplify lookups at the callsite.
extension [String: String] {
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

    func getBoolValue(_ key: OTel.Configuration.Key.GeneralKey) -> Bool? {
        getBoolValue(.single(key))
    }

    func getBoolValue(_ key: OTel.Configuration.Key.SignalSpecificKey, signal: OTel.Configuration.Key.Signal) -> Bool? {
        getBoolValue(.signalSpecific(key, signal))
    }

    func getIntegerValue(_ key: OTel.Configuration.Key.GeneralKey) -> Int? {
        getIntegerValue(.single(key))
    }

    func getIntegerValue(_ key: OTel.Configuration.Key.SignalSpecificKey, signal: OTel.Configuration.Key.Signal) -> Int? {
        getIntegerValue(.signalSpecific(key, signal))
    }

    func getDurationValue(_ key: OTel.Configuration.Key.GeneralKey) -> Duration? {
        getDurationValue(.single(key))
    }

    func getDurationValue(_ key: OTel.Configuration.Key.SignalSpecificKey, signal: OTel.Configuration.Key.Signal) -> Duration? {
        getDurationValue(.signalSpecific(key, signal))
    }

    func getTimeoutValue(_ key: OTel.Configuration.Key.GeneralKey) -> Duration? {
        getDurationValue(.single(key))
    }

    func getTimeoutValue(_ key: OTel.Configuration.Key.SignalSpecificKey, signal: OTel.Configuration.Key.Signal) -> Duration? {
        getDurationValue(.signalSpecific(key, signal))
    }

    func getHeadersValue(_ key: OTel.Configuration.Key.GeneralKey) -> [(String, String)]? {
        getHeadersValue(.single(key))
    }

    func getHeadersValue(_ key: OTel.Configuration.Key.SignalSpecificKey, signal: OTel.Configuration.Key.Signal) -> [(String, String)]? {
        getHeadersValue(.signalSpecific(key, signal))
    }

    func getEnumValue<E: RawRepresentable<String>>(of type: E.Type = E.self, _ key: OTel.Configuration.Key.GeneralKey) -> E? {
        getEnumValue(of: type, .single(key))
    }

    func getEnumValue<E: RawRepresentable<String>>(of type: E.Type = E.self, _ key: OTel.Configuration.Key.SignalSpecificKey, signal: OTel.Configuration.Key.Signal) -> E? {
        getEnumValue(of: type, .signalSpecific(key, signal))
    }
}

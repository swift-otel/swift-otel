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
package import Logging

extension OTel.Configuration {
    package mutating func applyEnvironmentOverrides(environment: [String: String], logger: Logger) {
        logs.disabled.override(using: .sdkDisabled, from: environment, logger: logger)
        metrics.disabled.override(using: .sdkDisabled, from: environment, logger: logger)
        traces.disabled.override(using: .sdkDisabled, from: environment, logger: logger)
        resourceAttributes.merge(using: .resourceAttributes, from: environment, logger: logger)
        serviceName.override(using: .serviceName, from: environment, logger: logger)
        diagnosticLogLevel.override(using: .logLevel, from: environment, logger: logger)
        propagators.override(using: .propagators, from: environment, logger: logger)
        traces.applyEnvironmentOverrides(environment: environment, logger: logger)
        metrics.applyEnvironmentOverrides(environment: environment, logger: logger)
        logs.applyEnvironmentOverrides(environment: environment, logger: logger)
    }
}

extension OTel.Configuration.TracesConfiguration {
    internal mutating func applyEnvironmentOverrides(environment: [String: String], logger: Logger) {
        sampler.applyEnvironmentOverrides(environment: environment, logger: logger)
        batchSpanProcessor.applyEnvironmentOverrides(environment: environment, logger: logger)
        exporter.override(using: .tracesExporter, from: environment, logger: logger)
        if exporter.backing == .none { enabled = false }
        otlpExporter.applyEnvironmentOverrides(environment: environment, signal: .traces, logger: logger)
    }
}

extension OTel.Configuration.MetricsConfiguration {
    internal mutating func applyEnvironmentOverrides(environment: [String: String], logger: Logger) {
        exportInterval.override(using: .metricExportInterval, from: environment, logger: logger)
        exportTimeout.override(using: .metricExportTimeout, from: environment, logger: logger)
        exporter.override(using: .metricsExporter, from: environment, logger: logger)
        if exporter.backing == .none { enabled = false }
        otlpExporter.applyEnvironmentOverrides(environment: environment, signal: .metrics, logger: logger)
    }
}

extension OTel.Configuration.LogsConfiguration {
    internal mutating func applyEnvironmentOverrides(environment: [String: String], logger: Logger) {
        batchLogRecordProcessor.applyEnvironmentOverrides(environment: environment, logger: logger)
        exporter.override(using: .logsExporter, from: environment, logger: logger)
        if exporter.backing == .none { enabled = false }
        otlpExporter.applyEnvironmentOverrides(environment: environment, signal: .logs, logger: logger)
    }
}

extension OTel.Configuration.TracesConfiguration.SamplerConfiguration {
    internal mutating func applyEnvironmentOverrides(environment: [String: String], logger: Logger) {
        backing.override(using: .sampler, from: environment, logger: logger)
        argument.override(for: backing, using: .samplerArgument, from: environment, logger: logger)
    }
}

extension OTel.Configuration.TracesConfiguration.BatchSpanProcessorConfiguration {
    internal mutating func applyEnvironmentOverrides(environment: [String: String], logger: Logger) {
        scheduleDelay.override(using: .batchSpanProcessorScheduleDelay, from: environment, logger: logger)
        exportTimeout.override(using: .batchSpanProcessorExportTimeout, from: environment, logger: logger)
        maxQueueSize.override(using: .batchSpanProcessorMaxQueueSize, from: environment, logger: logger)
        maxExportBatchSize.override(using: .batchSpanProcessorExportBatchSize, from: environment, logger: logger)
    }
}

extension OTel.Configuration.LogsConfiguration.BatchLogRecordProcessorConfiguration {
    internal mutating func applyEnvironmentOverrides(environment: [String: String], logger: Logger) {
        scheduleDelay.override(using: .batchLogRecordProcessorScheduleDelay, from: environment, logger: logger)
        exportTimeout.override(using: .batchLogRecordProcessorExportTimeout, from: environment, logger: logger)
        maxQueueSize.override(using: .batchLogRecordProcessorMaxQueueSize, from: environment, logger: logger)
        maxExportBatchSize.override(using: .batchLogRecordProcessorExportBatchSize, from: environment, logger: logger)
    }
}

extension OTel.Configuration.OTLPExporterConfiguration {
    internal mutating func applyEnvironmentOverrides(environment: [String: String], signal: OTel.Configuration.Key.Signal, logger: Logger) {
        let previousValue = self
        self.protocol.override(using: .otlpExporterProtocol, for: signal, from: environment, logger: logger)
        endpoint.override(using: .otlpExporterEndpoint, for: signal, from: environment, logger: logger)
        let key = OTel.Configuration.Key.SignalSpecificKey.otlpExporterEndpoint
        let signalSpecificKey = switch signal {
        case .traces: key.traces
        case .metrics: key.metrics
        case .logs: key.logs
        }
        switch (environment[key.shared], environment[signalSpecificKey]) {
        case (.some, .none): endpointHasBeenExplicitlySet = false
        case (_, .some): endpointHasBeenExplicitlySet = true
        case (.none, .none): endpointHasBeenExplicitlySet = previousValue.endpointHasBeenExplicitlySet
        }
        insecure.override(using: .otlpExporterInsecure, for: signal, from: environment, logger: logger)
        certificateFilePath.override(using: .otlpExporterCertificate, for: signal, from: environment, logger: logger)
        clientKeyFilePath.override(using: .otlpExporterClientKey, for: signal, from: environment, logger: logger)
        clientCertificateFilePath.override(using: .otlpExporterClientCertificate, for: signal, from: environment, logger: logger)
        headers.override(using: .otlpExporterHeaders, for: signal, from: environment, logger: logger)
        compression.override(using: .otlpExporterCompression, for: signal, from: environment, logger: logger)
        timeout.override(using: .otlpExporterTimeout, for: signal, from: environment, logger: logger)
    }
}

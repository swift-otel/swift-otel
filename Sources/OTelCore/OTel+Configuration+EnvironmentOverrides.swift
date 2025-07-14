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
    package mutating func applyEnvironmentOverrides(environment: [String: String]) {
        if let resourceAttributes = environment.getHeadersValue(.resourceAttributes) {
            // https://opentelemetry.io/docs/specs/otel/resource/sdk/#specifying-resource-information-via-an-environment-variable
            let incomingAttributes = Dictionary(resourceAttributes, uniquingKeysWith: { _, second in second })
            self.resourceAttributes.merge(incomingAttributes, uniquingKeysWith: { current, _ in current })
        }
        if let serviceName = environment.getStringValue(.serviceName) {
            self.serviceName = serviceName
        }
        if let diagnosticLogLevel = environment.getEnumValue(of: OTel.Configuration.LogLevel.Backing.self, .logLevel) {
            self.diagnosticLogLevel = .init(backing: diagnosticLogLevel)
        }
        if let propagators = environment.getStringValue(.propagators) {
            self.propagators.removeAll()
            for propagator in propagators.split(separator: ",") {
                switch propagator {
                case "tracecontext":
                    self.propagators.append(.traceContext)
                case "baggage":
                    self.propagators.append(.baggage)
                case "b3":
                    self.propagators.append(.b3)
                case "b3multi":
                    self.propagators.append(.b3Multi)
                case "jaeger":
                    self.propagators.append(.jaeger)
                case "xray":
                    self.propagators.append(.xray)
                case "ottrace":
                    self.propagators.append(.otTrace)
                case "none":
                    self.propagators.removeAll()
                default:
                    continue
                }
            }
        }
        traces.applyEnvironmentOverrides(environment: environment)
        metrics.applyEnvironmentOverrides(environment: environment)
        logs.applyEnvironmentOverrides(environment: environment)
    }
}

extension OTel.Configuration.TracesConfiguration {
    internal mutating func applyEnvironmentOverrides(environment: [String: String]) {
        sampler.applyEnvironmentOverrides(environment: environment)
        batchSpanProcessor.applyEnvironmentOverrides(environment: environment)
        if let tracesExporter = environment.getStringValue(.tracesExporter) {
            switch tracesExporter {
            case "none":
                enabled = false
            case "jaeger":
                exporter = .jaeger
            case "zipkin":
                exporter = .zipkin
            case "console":
                exporter = .console
            case "otlp":
                exporter = .otlp
            default:
                exporter = .otlp
            }
        }
        otlpExporter.applyEnvironmentOverrides(environment: environment, signal: .traces)
    }
}

extension OTel.Configuration.MetricsConfiguration {
    internal mutating func applyEnvironmentOverrides(environment: [String: String]) {
        if let metricExportInterval = environment.getDurationValue(.metricExportInterval) {
            exportInterval = metricExportInterval
        }
        if let metricExportTimeout = environment.getDurationValue(.metricExportTimeout) {
            exportTimeout = metricExportTimeout
        }
        if let metricsExporter = environment.getStringValue(.metricsExporter) {
            switch metricsExporter {
            case "none":
                enabled = false
            case "prometheus":
                exporter = .prometheus
            case "console":
                exporter = .console
            case "otlp":
                exporter = .otlp
            default:
                exporter = .otlp
            }
        }
        otlpExporter.applyEnvironmentOverrides(environment: environment, signal: .metrics)
    }
}

extension OTel.Configuration.LogsConfiguration {
    internal mutating func applyEnvironmentOverrides(environment: [String: String]) {
        batchLogRecordProcessor.applyEnvironmentOverrides(environment: environment)
        if let logsExporter = environment.getStringValue(.logsExporter) {
            switch logsExporter {
            case "none":
                enabled = false
            case "console":
                exporter = .console
            case "otlp":
                exporter = .otlp
            default:
                exporter = .otlp
            }
        }
        otlpExporter.applyEnvironmentOverrides(environment: environment, signal: .logs)
    }
}

extension OTel.Configuration.TracesConfiguration.SamplerConfiguration {
    internal mutating func applyEnvironmentOverrides(environment: [String: String]) {
        if let sampler = environment.getStringValue(.sampler) {
            switch sampler {
            case "always_on": self = .alwaysOn
            case "always_off": self = .alwaysOff
            case "traceidratio": backing = .traceIDRatio
            case "parentbased_always_on": self = .parentBasedAlwaysOn
            case "parentbased_always_off": self = .parentBasedAlwaysOff
            case "parentbased_traceidratio": backing = .parentBasedTraceIDRatio
            case "parentbased_jaeger_remote": self = .parentBasedJaegerRemote
            case "jaeger_remote": self = .jaegerRemote
            case "xray": self = .xray
            default: self = .parentBasedAlwaysOn
            }
        }
        if let samplerArgument = environment.getStringValue(.samplerArgument) {
            switch backing {
            case .traceIDRatio, .parentBasedTraceIDRatio:
                guard let samplingProbability = Double(samplerArgument) else { break }
                argument = .traceIDRatio(samplingProbability: samplingProbability)
            case .jaegerRemote, .parentBasedJaegerRemote:
                // Example: endpoint=http://localhost:14250,pollingIntervalMs=5000,initialSamplingRate=0.25
                let parameters = samplerArgument.split(separator: ",", maxSplits: 3).map { $0.split(separator: "=", maxSplits: 2) }
                guard
                    parameters.count == 3, parameters.allSatisfy({ $0.count == 2 }),
                    parameters[0][0] == "endpoint",
                    let endpoint = String(parameters[0][1]) as String?,
                    parameters[1][0] == "pollingIntervalMs",
                    let pollingIntervalMilliseconds = Int(parameters[1][1]),
                    parameters[2][0] == "initialSamplingRate",
                    let initialSamplingRate = Double(parameters[2][1])
                else { break }
                argument = .jaegerRemote(
                    endpoint: endpoint,
                    pollingInterval: .milliseconds(pollingIntervalMilliseconds),
                    initialSamplingRate: initialSamplingRate
                )
            default:
                break
            }
        }
    }
}

extension OTel.Configuration.TracesConfiguration.BatchSpanProcessorConfiguration {
    internal mutating func applyEnvironmentOverrides(environment: [String: String]) {
        if let scheduleDelay = environment.getDurationValue(.batchSpanProcessorScheduleDelay) {
            self.scheduleDelay = scheduleDelay
        }
        if let exportTimeout = environment.getTimeoutValue(.batchSpanProcessorExportTimeout) {
            self.exportTimeout = exportTimeout
        }
        if let maxQueueSize = environment.getIntegerValue(.batchSpanProcessorMaxQueueSize) {
            self.maxQueueSize = maxQueueSize
        }
        if let exportBatchSize = environment.getIntegerValue(.batchSpanProcessorExportBatchSize) {
            maxExportBatchSize = exportBatchSize
        }
    }
}

extension OTel.Configuration.LogsConfiguration.BatchLogRecordProcessorConfiguration {
    internal mutating func applyEnvironmentOverrides(environment: [String: String]) {
        if let scheduleDelay = environment.getDurationValue(.batchLogRecordProcessorScheduleDelay) {
            self.scheduleDelay = scheduleDelay
        }
        if let exportTimeout = environment.getTimeoutValue(.batchLogRecordProcessorExportTimeout) {
            self.exportTimeout = exportTimeout
        }
        if let maxQueueSize = environment.getIntegerValue(.batchLogRecordProcessorMaxQueueSize) {
            self.maxQueueSize = maxQueueSize
        }
        if let exportBatchSize = environment.getIntegerValue(.batchLogRecordProcessorExportBatchSize) {
            maxExportBatchSize = exportBatchSize
        }
    }
}

extension OTel.Configuration.OTLPExporterConfiguration {
    internal mutating func applyEnvironmentOverrides(environment: [String: String], signal: OTel.Configuration.Key.Signal) {
        if let `protocol` = environment.getStringValue(.otlpExporterProtocol, signal: signal) {
            switch `protocol` {
            case "http/json":
                #if OTLPHTTP
                self.protocol = .httpJSON
                #else // OTLPHTTP
                fatalError("Using the OTLP/HTTP + JSON exporter requires the `OTLPHTTP` trait enabled.")
                #endif
            case "grpc":
                #if OTLPGRPC
                self.protocol = .grpc
                #else // OTLPGRPC
                fatalError("Using the OTLP/GRPC exporter requires the `OTLPGRPC` trait enabled.")
                #endif
            case "http/protobuf":
                #if OTLPHTTP
                self.protocol = .httpProtobuf
                #else // OTLPHTTP
                fatalError("Using the OTLP/HTTP + Protobuf exporter requires the `OTLPHTTP` trait enabled.")
                #endif
            default:
                #if OTLPHTTP
                self.protocol = .httpProtobuf
                #else // OTLPHTTP
                fatalError("Using the OTLP/HTTP + Protobuf exporter requires the `OTLPHTTP` trait enabled.")
                #endif
            }
        }
        do {
            switch self.protocol.backing {
            case .grpc:
                // For OTLP/gRPC, we honor the endpoint as its been provided.
                if let endpoint = environment.getStringValue(.otlpExporterEndpoint, signal: signal) {
                    self.endpoint = endpoint
                }
            case .httpProtobuf, .httpJSON:
                // For OTLP/HTTP, how the endpoint is derrived depends on whether the shared and/or specific keys are set.
                // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#endpoint-urls-for-otlphttp
                let key = OTel.Configuration.Key.SignalSpecificKey.otlpExporterEndpoint
                let sharedKey = key.shared
                let (signalSpecificKey, signalSpecificEndpointSuffix) = switch signal {
                case .logs: (key.logs, "v1/logs")
                case .metrics: (key.metrics, "v1/metrics")
                case .traces: (key.traces, "v1/traces")
                }
                if let specificEndpoint = environment[signalSpecificKey] {
                    endpoint = specificEndpoint
                } else if let sharedEndpoint = environment[sharedKey] {
                    endpoint = sharedEndpoint
                    if !endpoint.hasSuffix("/") {
                        endpoint.append("/")
                    }
                    endpoint.append(signalSpecificEndpointSuffix)
                }
            }
        }
        if let insecure = environment.getBoolValue(.otlpExporterInsecure, signal: signal) {
            self.insecure = insecure
        }
        if let certificateFilePath = environment.getStringValue(.otlpExporterCertificate, signal: signal) {
            self.certificateFilePath = certificateFilePath
        }
        if let clientKeyFilePath = environment.getStringValue(.otlpExporterClientKey, signal: signal) {
            self.clientKeyFilePath = clientKeyFilePath
        }
        if let clientCertificateFilePath = environment.getStringValue(.otlpExporterClientCertificate, signal: signal) {
            self.clientCertificateFilePath = clientCertificateFilePath
        }
        if let headers = environment.getHeadersValue(.otlpExporterHeaders, signal: signal) {
            self.headers = headers
        }
        if let compression = environment.getStringValue(.otlpExporterCompression, signal: signal) {
            switch compression {
            case "gzip":
                self.compression = .gzip
            case "none":
                self.compression = .none
            default:
                self.compression = .none
            }
        }
        if let timeout = environment.getTimeoutValue(.otlpExporterTimeout, signal: signal) {
            self.timeout = timeout
        }
    }
}

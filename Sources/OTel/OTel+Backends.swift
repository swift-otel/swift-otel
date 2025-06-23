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

import CoreMetrics
import Logging
import OTelCore
import ServiceLifecycle
import Tracing
#if OTLPGRPC
    import OTLPGRPC
#endif
#if OTLPHTTP
    import OTLPHTTP
#endif

extension OTel {
    public static func makeLoggingBackend(configuration: OTel.Configuration = .default) throws -> (factory: @Sendable (String) -> any LogHandler, service: some Service) {
        throw NotImplementedError()
        // The following placeholder code exists only to type check the opaque return type.
        let factory: (@Sendable (String) -> any LogHandler)! = nil
        let service: ServiceGroup! = nil
        return (factory, service)
    }

    public static func makeMetricsBackend(configuration: OTel.Configuration = .default) throws -> (factory: any MetricsFactory, service: some Service) {
        let resource = OTelResource(configuration: configuration)
        let registry = OTelMetricRegistry()
        let metricsExporter: OTelMetricExporter
        switch configuration.metrics.exporter.backing {
        case .otlp:
            switch configuration.metrics.otlpExporter.protocol.backing {
            case .grpc:
                #if OTLPGRPC
                    metricsExporter = try OTLPGRPCMetricExporter(configuration: configuration.metrics.otlpExporter)
                #else // OTLPGRPC
                    fatalError("Using the OTLP/GRPC exporter requires the `OTLPGRPC` trait enabled.")
                #endif
            case .httpProtobuf, .httpJSON:
                #if OTLPHTTP
                    metricsExporter = try OTLPHTTPMetricExporter(configuration: configuration.metrics.otlpExporter)
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

        let reader = OTelPeriodicExportingMetricsReader(resource: resource, producer: registry, exporter: metricsExporter, configuration: readerConfig)

        return (OTLPMetricsFactory(registry: registry), reader)
    }

    public static func makeTracingBackend(configuration: OTel.Configuration = .default) throws -> (factory: any Tracing.Tracer, service: some Service) {
        throw NotImplementedError()
        // The following placeholder code exists only to type check the opaque return type.
        let factory: (any Tracing.Tracer)! = nil
        let service: ServiceGroup! = nil
        return (factory, service)
    }
}

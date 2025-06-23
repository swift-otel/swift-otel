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
    public static func makeLoggingBackend(configuration: OTel.Configuration = .default) throws -> (factory: @Sendable (String) -> any LogHandler, service: some Service) {
        /// This is necessary because the processor is generic over the exporter and we need to return an opaque type.
        struct Wrapper: Service {
            var wrapped: any Service
            func run() async throws {
                try await wrapped.run()
            }
        }

        let resource = OTelResource(configuration: configuration)
        switch configuration.logs.exporter.backing {
        case .otlp:
            switch configuration.logs.otlpExporter.protocol.backing {
            case .grpc:
                #if OTLPGRPC
                let exporter = try OTLPGRPCLogRecordExporter(configuration: configuration.logs.otlpExporter)
                let processor = OTelBatchLogRecordProcessor(exporter: exporter, configuration: .init(configuration: configuration.logs.batchLogRecordProcessor))
                let handler = OTelLogHandler(
                    processor: processor,
                    logLevel: .debug, // um.... wat?
                    resource: resource
                )
                return ({ _ in handler }, Wrapper(wrapped: processor))
                #else // OTLPGRPC
                fatalError("Using the OTLP/GRPC exporter requires the `OTLPGRPC` trait enabled.")
                #endif
            case .httpProtobuf, .httpJSON:
                #if OTLPHTTP
                let exporter = try OTLPHTTPLogRecordExporter(configuration: configuration.logs.otlpExporter)
                let processor: OTelBatchLogRecordProcessor = .init(
                    exporter: exporter,
                    configuration: OTelBatchLogRecordProcessorConfiguration(environment: .detected()) // TODO: shim
                )
                let handler = OTelLogHandler(
                    processor: processor,
                    logLevel: .debug, // um.... wat?
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

        let resource = OTelResource(configuration: configuration)
        switch configuration.traces.exporter.backing {
        case .otlp:
            switch configuration.traces.otlpExporter.protocol.backing {
            case .grpc:
                #if OTLPGRPC
                let exporter = try OTLPGRPCSpanExporter(configuration: configuration.traces.otlpExporter)
                let processor = OTelBatchSpanProcessor(exporter: exporter, configuration: .init(configuration: configuration.traces.batchSpanProcessor))
                let tracer = OTelTracer(
                    idGenerator: OTelRandomIDGenerator(),
                    sampler: OTelConstantSampler(isOn: true),
                    propagator: OTelW3CPropagator(),
                    processor: processor,
                    environment: .detected(),
                    resource: resource
                )
                return (tracer, TracerWrapper(wrapped: tracer))
                #else // OTLPGRPC
                fatalError("Using the OTLP/GRPC exporter requires the `OTLPGRPC` trait enabled.")
                #endif
            case .httpProtobuf, .httpJSON:
                #if OTLPHTTP
                let exporter = try OTLPHTTPSpanExporter(configuration: configuration.traces.otlpExporter)
                let processor = OTelBatchSpanProcessor(exporter: exporter, configuration: .init(configuration: configuration.traces.batchSpanProcessor))
                let tracer = OTelTracer(
                    idGenerator: OTelRandomIDGenerator(),
                    sampler: OTelConstantSampler(isOn: true),
                    propagator: OTelW3CPropagator(),
                    processor: processor,
                    environment: .detected(),
                    resource: resource
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

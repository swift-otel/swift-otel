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

    public static func makeMetricsBackend(configuration: OTel.Configuration = .default) throws -> (factory: any CoreMetrics.MetricsFactory, service: some Service) {
        throw NotImplementedError()
        // The following placeholder code exists only to type check the opaque return type.
        let factory: (any CoreMetrics.MetricsFactory)! = nil
        let service: ServiceGroup! = nil
        return (factory, service)
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

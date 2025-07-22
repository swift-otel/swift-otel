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

import OTelCore
#if OTLPGRPC
import OTLPGRPC
#endif
#if OTLPHTTP
import OTLPHTTP
#endif
import Logging
import Tracing
import W3CTraceContext

/// The wrapper types in this file exist to support our simplified public API surface.
///
/// The backing implementation for much of this library is comprised of layered generic types, for example:
///
/// ```swift
/// OTelTracer<
///   OTelRandomIDGenerator<SystemRandomNumberGenerator>,
///   OTelTraceIDRatioBasedSampler,
///   OTelW3CPropagator,
///   OTelBatchSpanProcessor<OTLPHTTPSpanExporter, ContinuousClock>,
///   ContinuousClock
/// >
/// ```
///
/// Our public API does not expose these open types and instead provides a config-based API that return an opaque
/// concrete type. When returning opaque types, the type must still be known at compile time and be the same type
/// on all branches.
///
/// This can be achieved in two ways:
///
/// 1. Return a concrete wrapper type that holds an existential.
/// 2. Return a concrete wrapper type that is an enum.
///
/// (1) is a poor trade for APIs that return only a fixed set of types since we introduce an existential, which may
/// have performance implications.
///
/// (2) is a better choice for a closed set of types since it introduces minimal overhead.
///
/// Note that, in order to abstract over platform availability and provide the package on older platforms that are not
/// supported by gRPC Swift v2, some of the below wrapper enums _do_ hold an existential in one of their cases. In this
/// case, they still add value because they:
///
/// (a) Allow us to remove the existential from the API surface.
/// (b) Allow us to remove the existential completely for the OTLP/HTTP exporter.

internal enum WrappedLogRecordExporter: OTelLogRecordExporter {
    #if OTLPGRPC
    case grpc(any OTelLogRecordExporter)
    #endif
    #if OTLPHTTP
    case http(OTLPHTTPLogRecordExporter)
    #endif

    func run() async throws {
        switch self {
        #if OTLPGRPC
        case .grpc(let exporter): try await exporter.run()
        #endif
        #if OTLPHTTP
        case .http(let exporter): try await exporter.run()
        #endif
        }
    }

    func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws {
        switch self {
        #if OTLPGRPC
        case .grpc(let exporter): try await exporter.export(batch)
        #endif
        #if OTLPHTTP
        case .http(let exporter): try await exporter.export(batch)
        #endif
        }
    }

    func forceFlush() async throws {
        switch self {
        #if OTLPGRPC
        case .grpc(let exporter): try await exporter.forceFlush()
        #endif
        #if OTLPHTTP
        case .http(let exporter): try await exporter.forceFlush()
        #endif
        }
    }

    func shutdown() async {
        switch self {
        #if OTLPGRPC
        case .grpc(let exporter): await exporter.shutdown()
        #endif
        #if OTLPHTTP
        case .http(let exporter): await exporter.shutdown()
        #endif
        }
    }

    init(configuration: OTel.Configuration, logger: Logger) throws {
        switch configuration.logs.exporter.backing {
        case .otlp:
            switch configuration.logs.otlpExporter.protocol.backing {
            case .grpc:
                #if OTLPGRPC
                if #available(gRPCSwift, *) {
                    let exporter = try OTLPGRPCLogRecordExporter(configuration: configuration.logs.otlpExporter, logger: logger)
                    self = .grpc(exporter)
                } else {
                    fatalError("Using the OTLP/gRPC exporter is not supported on this platform.")
                }
                #else // OTLPGRPC
                fatalError("Using the OTLP/gRPC exporter requires the `OTLPGRPC` trait enabled.")
                #endif
            case .httpProtobuf, .httpJSON:
                #if OTLPHTTP
                let exporter = try OTLPHTTPLogRecordExporter(configuration: configuration.logs.otlpExporter, logger: logger)
                self = .http(exporter)
                #else
                fatalError("Using the OTLP/HTTP exporter requires the `OTLPHTTP` trait enabled.")
                #endif
            }
        case .console:
            throw NotImplementedError()
        case .none: preconditionFailure()
        }
    }
}

internal enum WrappedMetricExporter: OTelMetricExporter {
    #if OTLPGRPC
    case grpc(any OTelMetricExporter)
    #endif
    #if OTLPHTTP
    case http(OTLPHTTPMetricExporter)
    #endif

    func run() async throws {
        switch self {
        #if OTLPGRPC
        case .grpc(let exporter): try await exporter.run()
        #endif
        #if OTLPHTTP
        case .http(let exporter): try await exporter.run()
        #endif
        }
    }

    func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws {
        switch self {
        #if OTLPGRPC
        case .grpc(let exporter): try await exporter.export(batch)
        #endif
        #if OTLPHTTP
        case .http(let exporter): try await exporter.export(batch)
        #endif
        }
    }

    func forceFlush() async throws {
        switch self {
        #if OTLPGRPC
        case .grpc(let exporter): try await exporter.forceFlush()
        #endif
        #if OTLPHTTP
        case .http(let exporter): try await exporter.forceFlush()
        #endif
        }
    }

    func shutdown() async {
        switch self {
        #if OTLPGRPC
        case .grpc(let exporter): await exporter.shutdown()
        #endif
        #if OTLPHTTP
        case .http(let exporter): await exporter.shutdown()
        #endif
        }
    }

    init(configuration: OTel.Configuration, logger: Logger) throws {
        switch configuration.metrics.exporter.backing {
        case .otlp:
            switch configuration.metrics.otlpExporter.protocol.backing {
            case .grpc:
                #if OTLPGRPC
                if #available(gRPCSwift, *) {
                    let exporter = try OTLPGRPCMetricExporter(configuration: configuration.metrics.otlpExporter, logger: logger)
                    self = .grpc(exporter)
                } else {
                    fatalError("Using the OTLP/gRPC exporter is not supported on this platform.")
                }
                #else // OTLPGRPC
                fatalError("Using the OTLP/gRPC exporter requires the `OTLPGRPC` trait enabled.")
                #endif
            case .httpProtobuf, .httpJSON:
                #if OTLPHTTP
                let exporter = try OTLPHTTPMetricExporter(configuration: configuration.metrics.otlpExporter, logger: logger)
                self = .http(exporter)
                #else
                fatalError("Using the OTLP/HTTP exporter requires the `OTLPHTTP` trait enabled.")
                #endif
            }
        case .prometheus, .console:
            throw NotImplementedError()
        case .none: preconditionFailure()
        }
    }
}

internal enum WrappedSpanExporter: OTelSpanExporter {
    #if OTLPGRPC
    case grpc(any OTelSpanExporter)
    #endif
    #if OTLPHTTP
    case http(OTLPHTTPSpanExporter)
    #endif

    func run() async throws {
        switch self {
        #if OTLPGRPC
        case .grpc(let exporter): try await exporter.run()
        #endif
        #if OTLPHTTP
        case .http(let exporter): try await exporter.run()
        #endif
        }
    }

    func export(_ batch: some Collection<OTelFinishedSpan> & Sendable) async throws {
        switch self {
        #if OTLPGRPC
        case .grpc(let exporter): try await exporter.export(batch)
        #endif
        #if OTLPHTTP
        case .http(let exporter): try await exporter.export(batch)
        #endif
        }
    }

    func forceFlush() async throws {
        switch self {
        #if OTLPGRPC
        case .grpc(let exporter): try await exporter.forceFlush()
        #endif
        #if OTLPHTTP
        case .http(let exporter): try await exporter.forceFlush()
        #endif
        }
    }

    func shutdown() async {
        switch self {
        #if OTLPGRPC
        case .grpc(let exporter): await exporter.shutdown()
        #endif
        #if OTLPHTTP
        case .http(let exporter): await exporter.shutdown()
        #endif
        }
    }

    init(configuration: OTel.Configuration, logger: Logger) throws {
        switch configuration.traces.exporter.backing {
        case .otlp:
            switch configuration.traces.otlpExporter.protocol.backing {
            case .grpc:
                #if OTLPGRPC
                if #available(gRPCSwift, *) {
                    let exporter = try OTLPGRPCSpanExporter(configuration: configuration.traces.otlpExporter, logger: logger)
                    self = .grpc(exporter)
                } else {
                    fatalError("Using the OTLP/gRPC exporter is not supported on this platform.")
                }
                #else // OTLPGRPC
                fatalError("Using the OTLP/gRPC exporter requires the `OTLPGRPC` trait enabled.")
                #endif
            case .httpProtobuf, .httpJSON:
                #if OTLPHTTP
                let exporter = try OTLPHTTPSpanExporter(configuration: configuration.traces.otlpExporter, logger: logger)
                self = .http(exporter)
                #else
                fatalError("Using the OTLP/HTTP exporter requires the `OTLPHTTP` trait enabled.")
                #endif
            }
        case .console, .jaeger, .zipkin:
            throw NotImplementedError()
        case .none: preconditionFailure()
        }
    }
}

internal enum WrappedSampler: OTelSampler {
    case alwaysOn(OTelConstantSampler)
    case alwaysOff(OTelConstantSampler)
    case traceIDRatio(OTelTraceIDRatioBasedSampler)
    case parentBasedAlwaysOn(OTelParentBasedSampler)
    case parentBasedAlwaysOff(OTelParentBasedSampler)
    case parentBasedTraceIDRatio(OTelParentBasedSampler)

    func samplingResult(operationName: String, kind: SpanKind, traceID: TraceID, attributes: SpanAttributes, links: [SpanLink], parentContext: ServiceContext) -> OTelSamplingResult {
        switch self {
        case .alwaysOn(let wrapped), .alwaysOff(let wrapped):
            wrapped.samplingResult(operationName: operationName, kind: kind, traceID: traceID, attributes: attributes, links: links, parentContext: parentContext)
        case .traceIDRatio(let wrapped):
            wrapped.samplingResult(operationName: operationName, kind: kind, traceID: traceID, attributes: attributes, links: links, parentContext: parentContext)
        case .parentBasedAlwaysOn(let wrapped), .parentBasedAlwaysOff(let wrapped), .parentBasedTraceIDRatio(let wrapped):
            wrapped.samplingResult(operationName: operationName, kind: kind, traceID: traceID, attributes: attributes, links: links, parentContext: parentContext)
        }
    }

    init(configuration: OTel.Configuration) {
        switch configuration.traces.sampler.backing {
        case .alwaysOn: self = .alwaysOn(OTelConstantSampler(isOn: true))
        case .alwaysOff: self = .alwaysOff(OTelConstantSampler(isOn: false))
        case .traceIDRatio:
            switch configuration.traces.sampler.argument {
            case .traceIDRatio(let samplingProbability):
                self = .traceIDRatio(OTelTraceIDRatioBasedSampler(ratio: samplingProbability))
            default:
                self = .traceIDRatio(OTelTraceIDRatioBasedSampler(ratio: 1.0))
            }
        case .parentBasedAlwaysOn: self = .parentBasedAlwaysOn(OTelParentBasedSampler(rootSampler: OTelConstantSampler(isOn: true)))
        case .parentBasedAlwaysOff: self = .parentBasedAlwaysOff(OTelParentBasedSampler(rootSampler: OTelConstantSampler(isOn: false)))
        case .parentBasedTraceIDRatio:
            switch configuration.traces.sampler.argument {
            case .traceIDRatio(let samplingProbability):
                self = .parentBasedTraceIDRatio(OTelParentBasedSampler(rootSampler: OTelTraceIDRatioBasedSampler(ratio: samplingProbability)))
            default:
                self = .parentBasedTraceIDRatio(OTelParentBasedSampler(rootSampler: OTelTraceIDRatioBasedSampler(ratio: 1.0)))
            }
        case .parentBasedJaegerRemote: fatalError("Swift OTel does not support the parent-based Jaeger sampler")
        case .jaegerRemote: fatalError("Swift OTel does not support the Jaeger sampler")
        case .xray: fatalError("Swift OTel does not support the X-Ray sampler")
        }
    }
}

extension OTelMultiplexPropagator {
    init(configuration: OTel.Configuration) {
        var propagators: [OTelPropagator] = []
        loop: for propagatorConfigValue in configuration.propagators {
            switch propagatorConfigValue.backing {
            case .none:
                propagators.removeAll()
                break loop // If none is in the config, we'll assume that was deliberate and short-circuit here.
            case .traceContext: propagators.append(OTelW3CPropagator())
            case .baggage: fatalError("Swift OTel does not support the W3C Baggage propagator")
            case .b3: fatalError("Swift OTel does not support the B3 Single propagator")
            case .b3Multi: fatalError("Swift OTel does not support the B3 Multi propagator")
            case .jaeger: fatalError("Swift OTel does not support the Jaeger propagator")
            case .xray: fatalError("Swift OTel does not support the AWS X-Ray propagator")
            case .otTrace: fatalError("Swift OTel does not support the OT Trace propagator")
            }
        }
        self.init(propagators)
    }
}

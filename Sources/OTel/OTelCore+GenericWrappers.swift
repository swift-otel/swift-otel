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

internal enum WrappedLogRecordExporter: OTelLogRecordExporter {
    case grpc(OTLPGRPCLogRecordExporter)
    case http(OTLPHTTPLogRecordExporter)

    func run() async throws {
        switch self {
        case .grpc(let exporter): try await exporter.run()
        case .http(let exporter): try await exporter.run()
        }
    }

    func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws {
        switch self {
        case .grpc(let exporter): try await exporter.export(batch)
        case .http(let exporter): try await exporter.export(batch)
        }
    }

    func forceFlush() async throws {
        switch self {
        case .grpc(let exporter): try await exporter.forceFlush()
        case .http(let exporter): try await exporter.forceFlush()
        }
    }

    func shutdown() async {
        switch self {
        case .grpc(let exporter): await exporter.shutdown()
        case .http(let exporter): await exporter.shutdown()
        }
    }

    init(configuration: OTel.Configuration, logger: Logger) throws {
        switch configuration.logs.exporter.backing {
        case .otlp:
            switch configuration.logs.otlpExporter.protocol.backing {
            case .grpc:
                #if OTLPGRPC
                let exporter = try OTLPGRPCLogRecordExporter(configuration: configuration.logs.otlpExporter, logger: logger)
                self = .grpc(exporter)
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
        }
    }
}

internal enum WrappedMetricExporter: OTelMetricExporter {
    case grpc(OTLPGRPCMetricExporter)
    case http(OTLPHTTPMetricExporter)

    func run() async throws {
        switch self {
        case .grpc(let exporter): try await exporter.run()
        case .http(let exporter): try await exporter.run()
        }
    }

    func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws {
        switch self {
        case .grpc(let exporter): try await exporter.export(batch)
        case .http(let exporter): try await exporter.export(batch)
        }
    }

    func forceFlush() async throws {
        switch self {
        case .grpc(let exporter): try await exporter.forceFlush()
        case .http(let exporter): try await exporter.forceFlush()
        }
    }

    func shutdown() async {
        switch self {
        case .grpc(let exporter): await exporter.shutdown()
        case .http(let exporter): await exporter.shutdown()
        }
    }

    init(configuration: OTel.Configuration, logger: Logger) throws {
        switch configuration.metrics.exporter.backing {
        case .otlp:
            switch configuration.metrics.otlpExporter.protocol.backing {
            case .grpc:
                #if OTLPGRPC
                let exporter = try OTLPGRPCMetricExporter(configuration: configuration.metrics.otlpExporter, logger: logger)
                self = .grpc(exporter)
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
        }
    }
}

internal enum WrappedSpanExporter: OTelSpanExporter {
    case grpc(OTLPGRPCSpanExporter)
    case http(OTLPHTTPSpanExporter)

    func run() async throws {
        switch self {
        case .grpc(let exporter): try await exporter.run()
        case .http(let exporter): try await exporter.run()
        }
    }

    func export(_ batch: some Collection<OTelFinishedSpan> & Sendable) async throws {
        switch self {
        case .grpc(let exporter): try await exporter.export(batch)
        case .http(let exporter): try await exporter.export(batch)
        }
    }

    func forceFlush() async throws {
        switch self {
        case .grpc(let exporter): try await exporter.forceFlush()
        case .http(let exporter): try await exporter.forceFlush()
        }
    }

    func shutdown() async {
        switch self {
        case .grpc(let exporter): await exporter.shutdown()
        case .http(let exporter): await exporter.shutdown()
        }
    }

    init(configuration: OTel.Configuration, logger: Logger) throws {
        switch configuration.traces.exporter.backing {
        case .otlp:
            switch configuration.traces.otlpExporter.protocol.backing {
            case .grpc:
                #if OTLPGRPC
                let exporter = try OTLPGRPCSpanExporter(configuration: configuration.traces.otlpExporter, logger: logger)
                self = .grpc(exporter)
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
        }
    }
}

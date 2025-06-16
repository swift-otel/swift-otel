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

import Logging

extension OTel {
    public struct Configuration: Sendable {
        public var serviceName: String
        public var resourceAttributes: [String: String]
        public var logger: LoggerSelection
        public var logLevel: LogLevel
        public var propagators: [Propagator]
        public var traces: TracesConfiguration
        public var metrics: MetricsConfiguration
        public var logs: LogsConfiguration

        public static let `default`: Self = .init(
            serviceName: "unknown_service",
            resourceAttributes: [:],
            logger: .console,
            logLevel: .info,
            propagators: [.traceContext, .baggage],
            traces: .default,
            metrics: .default,
            logs: .default
        )
    }
}

extension OTel.Configuration {
    public struct LoggerSelection: Sendable {
        package enum Backing: Sendable {
            case console
            case custom(Logger)
        }

        package var backing: Backing

        public static let console: Self = .init(backing: .console)
        public static func custom(_ logger: Logger) -> Self { .init(backing: .custom(logger)) }
    }
}

extension OTel.Configuration {
    public struct LogLevel: Sendable {
        package enum Backing: String, Sendable {
            case error
            case warning
            case info
            case debug
        }

        package var backing: Backing

        public static let error: Self = .init(backing: .error)
        public static let warning: Self = .init(backing: .warning)
        public static let info: Self = .init(backing: .info)
        public static let debug: Self = .init(backing: .debug)
    }
}

extension OTel.Configuration {
    public struct Propagator: Sendable {
        package enum Backing: Sendable {
            case traceContext
            case baggage
            case b3
            case b3Multi
            case jaeger
            case xray
            case otTrace
            case none
        }

        package var backing: Backing

        public static let traceContext: Self = .init(backing: .traceContext)
        public static let baggage: Self = .init(backing: .baggage)
        public static let b3: Self = .init(backing: .b3)
        public static let b3Multi: Self = .init(backing: .b3Multi)
        public static let jaeger: Self = .init(backing: .jaeger)
        public static let xray: Self = .init(backing: .xray)
        public static let otTrace: Self = .init(backing: .otTrace)
        public static let none: Self = .init(backing: .none)
    }
}

extension OTel.Configuration {
    public struct TracesConfiguration: Sendable {
        public var enabled: Bool
        public var batchSpanProcessor: BatchSpanProcessorConfiguration
        public var exporter: ExporterSelection
        public var otlpExporter: OTLPExporterConfiguration

        public static let `default`: Self = .init(
            enabled: true,
            batchSpanProcessor: .default,
            exporter: .otlp,
            otlpExporter: .default
        )
    }

    public struct MetricsConfiguration: Sendable {
        public var enabled: Bool
        public var exportInterval: Duration
        public var exportTimeout: Duration
        public var exporter: ExporterSelection
        public var otlpExporter: OTLPExporterConfiguration

        public static let `default`: Self = .init(
            enabled: true,
            exportInterval: .seconds(60),
            exportTimeout: .seconds(30),
            exporter: .otlp,
            otlpExporter: .default
        )
    }

    public struct LogsConfiguration: Sendable {
        public var enabled: Bool
        public var exporter: ExporterSelection
        public var otlpExporter: OTLPExporterConfiguration

        public static let `default`: Self = .init(
            enabled: true,
            exporter: .otlp,
            otlpExporter: .default
        )
    }
}

extension OTel.Configuration.TracesConfiguration {
    public struct BatchSpanProcessorConfiguration: Sendable {
        public var scheduleDelay: Duration
        public var exportTimeout: Duration
        public var maxQueueSize: Int
        public var maxExportBatchSize: Int

        public static let `default`: Self = .init(
            scheduleDelay: .seconds(5),
            exportTimeout: .seconds(30),
            maxQueueSize: 2048,
            maxExportBatchSize: 512
        )
    }
}

extension OTel.Configuration.TracesConfiguration {
    public struct ExporterSelection: Sendable {
        package enum Backing: Sendable {
            case otlp
            case jaeger
            case zipkin
            case console
        }

        package var backing: Backing

        public static let otlp: Self = .init(backing: .otlp)
        public static let jaeger: Self = .init(backing: .jaeger)
        public static let zipkin: Self = .init(backing: .zipkin)
        public static let console: Self = .init(backing: .console)
    }
}

extension OTel.Configuration.MetricsConfiguration {
    public struct ExporterSelection: Sendable {
        package enum Backing: Sendable {
            case otlp
            case prometheus
            case console
        }

        package var backing: Backing

        public static let otlp: Self = .init(backing: .otlp)
        public static let prometheus: Self = .init(backing: .prometheus)
        public static let console: Self = .init(backing: .console)
    }
}

extension OTel.Configuration.LogsConfiguration {
    public struct ExporterSelection: Sendable {
        package enum Backing: Sendable {
            case otlp
            case console
        }

        package var backing: Backing

        public static let otlp: Self = .init(backing: .otlp)
        public static let console: Self = .init(backing: .console)
    }
}

extension OTel.Configuration {
    public struct OTLPExporterConfiguration: Sendable {
        public var endpoint: String
        public var insecure: Bool
        public var certificateFilePath: String?
        public var clientKeyFilePath: String?
        public var clientCertificateFilePath: String?
        public var headers: [(String, String)]
        public var compression: Compression
        public var timeout: Duration
        public var `protocol`: Protocol

        public static let `default`: Self = .init(
            endpoint: "http://localhost:4318",
            insecure: false,
            certificateFilePath: nil,
            clientKeyFilePath: nil,
            clientCertificateFilePath: nil,
            headers: [],
            compression: .none,
            timeout: .seconds(10),
            protocol: .httpProtobuf
        )
    }
}

extension OTel.Configuration.OTLPExporterConfiguration {
    public struct Compression: Sendable {
        package enum Backing {
            case gzip
            case none
        }

        package var backing: Backing

        public static let none: Self = .init(backing: .none)
        public static let gzip: Self = .init(backing: .gzip)
    }

    // swiftformat:disable:next redundantBackticks
    public struct `Protocol`: Equatable, Sendable {
        package enum Backing {
            case grpc
            case httpProtobuf
            case httpJSON
        }

        package var backing: Backing

        // swiftformat:disable indent
        #if !OTLPGRPC
        @available(*, unavailable, message: "Using the OTLP/gRPC exporter requires the `OTLPGRPC` trait enabled.")
        #endif
        // swiftformat:enable indent
        public static let grpc: Self = .init(backing: .grpc)

        // swiftformat:disable indent
        #if !OTLPHTTP
        @available(*, unavailable, message: "Using the OTLP/HTTP exporter requires the `OTLPHTTP` trait enabled.")
        #endif
        // swiftformat:enable indent
        public static let httpProtobuf: Self = .init(backing: .httpProtobuf)

        // swiftformat:disable indent
        #if !OTLPHTTP
        @available(*, unavailable, message: "Using the OTLP/HTTP exporter requires the `OTLPHTTP` trait enabled.")
        #endif
        // swiftformat:enable indent
        public static let httpJSON: Self = .init(backing: .httpJSON)
    }
}

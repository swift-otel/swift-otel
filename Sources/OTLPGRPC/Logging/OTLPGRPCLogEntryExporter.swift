//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2024 Moritz Lang and the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import GRPC
import Logging
import NIO
import NIOHPACK
import NIOSSL
@_spi(Logging) import OTel
@_spi(Logging) import OTLPCore

/// Exports logs to an OTel collector using OTLP/gRPC.
@_spi(Logging)
public final class OTLPGRPCLogEntryExporter: OTelLogRecordExporter {
    private let configuration: OTLPGRPCLogEntryExporterConfiguration
    private let connection: ClientConnection
    private let client: Opentelemetry_Proto_Collector_Logs_V1_LogsServiceAsyncClient
    private let logger = Logger(label: String(describing: OTLPGRPCLogEntryExporter.self))

    public init(
        configuration: OTLPGRPCLogEntryExporterConfiguration,
        group: EventLoopGroup = MultiThreadedEventLoopGroup.singleton,
        requestLogger: Logger = ._otelDisabled,
        backgroundActivityLogger: Logger = ._otelDisabled
    ) {
        self.configuration = configuration

        var connectionConfiguration = ClientConnection.Configuration.default(
            target: .host(configuration.endpoint.host, port: configuration.endpoint.port),
            eventLoopGroup: group
        )

        if configuration.endpoint.isInsecure {
            logger.debug("Using insecure connection.", metadata: [
                "host": "\(configuration.endpoint.host)",
                "port": "\(configuration.endpoint.port)",
            ])
        }
    
        // TODO: Support OTEL_EXPORTER_OTLP_CERTIFICATE
        // TODO: Support OTEL_EXPORTER_OTLP_CLIENT_KEY
        // TODO: Support OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE

        var headers = configuration.headers
        if !headers.isEmpty {
            logger.trace("Configured custom request headers.", metadata: [
                "keys": .array(headers.map { "\($0.name)" }),
            ])
        }
        headers.replaceOrAdd(name: "user-agent", value: "OTel-OTLP-Exporter-Swift/\(OTelLibrary.version)")

        connectionConfiguration.backgroundActivityLogger = backgroundActivityLogger
        connection = ClientConnection(configuration: connectionConfiguration)

        client = Opentelemetry_Proto_Collector_Logs_V1_LogsServiceAsyncClient(
            channel: connection,
            defaultCallOptions: .init(customMetadata: headers, logger: requestLogger)
        )
    }

    public func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws {
        if case .shutdown = connection.connectivity.state {
            throw OTelLogRecordExporterAlreadyShutDownError()
        }

        guard !batch.isEmpty else { return }

        let request = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
            request.resourceLogs = [
                Opentelemetry_Proto_Logs_V1_ResourceLogs.with { resourceLog in
                    resourceLog.scopeLogs = [
                        Opentelemetry_Proto_Logs_V1_ScopeLogs.with { scopeLog in
                            scopeLog.logRecords = batch.map { log in
                                Opentelemetry_Proto_Logs_V1_LogRecord.with { logRecord in
                                    logRecord.timeUnixNano = log.timeNanosecondsSinceEpoch
                                    logRecord.observedTimeUnixNano = log.timeNanosecondsSinceEpoch
                                    logRecord.severityNumber = switch log.level {
                                    case .trace: .trace
                                    case .debug: .debug
                                    case .info: .info
                                    case .notice: .info4
                                    case .warning: .warn
                                    case .error: .error
                                    case .critical: .fatal
                                    }
                                    logRecord.severityText = switch log.level {
                                    case .trace: "TRACE"
                                    case .debug: "DEUG"
                                    case .info: "INFO"
                                    case .notice: "NOTICE"
                                    case .warning: "WARNING"
                                    case .error: "ERROR"
                                    case .critical: "CRITICAL"
                                    }

                                    logRecord.attributes = .init(log.metadata)
                                    logRecord.body = .with { body in
                                        body.stringValue = log.body.description
                                    }
                                }
                            }
                        }
                    ]
                }
            ]
        }

        _ = try await client.export(request)
    }

    public func forceFlush() async throws {}

    public func shutdown() async {
        let promise = connection.eventLoop.makePromise(of: Void.self)

        connection.closeGracefully(deadline: .now() + .milliseconds(500), promise: promise)

        try? await promise.futureResult.get()
    }
}

@_spi(Logging)
extension [Opentelemetry_Proto_Common_V1_KeyValue] {
    package init(_ metadata: Logger.Metadata) {
        self = metadata.map { key, value in
            return .with { attribute in
                attribute.key = key
                attribute.value = .init(value)
            }
        }
    }
}

@_spi(Logging)
extension Opentelemetry_Proto_Common_V1_KeyValueList {
    package init(_ metadata: Logger.Metadata) {
        self = .with { keyValueList in
            keyValueList.values = .init(metadata)
        }
    }
}

@_spi(Logging)
extension Opentelemetry_Proto_Common_V1_AnyValue {
    package init(_ value: Logger.Metadata.Value) {
        self = .with { attributeValue in
            attributeValue.value = switch value {
            case .string(let string): .stringValue(string)
            case .stringConvertible(let stringConvertible): .stringValue(stringConvertible.description)
            case .dictionary(let metadata): .kvlistValue(.init(metadata))
            case .array(let values): .arrayValue(.init(values))
            }
        }
    }
}

@_spi(Logging)
extension Opentelemetry_Proto_Common_V1_ArrayValue {
    package init(_ values: [Logger.Metadata.Value]) {
        self = .with { valueList in
            valueList.values = values.map(Opentelemetry_Proto_Common_V1_AnyValue.init)
        }
    }
}

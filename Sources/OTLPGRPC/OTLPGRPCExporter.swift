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

import struct Foundation.URLComponents
import GRPC
import Logging
import NIO
import NIOHPACK
import NIOSSL
import OTelCore

/// Unifying protocol for shared OTLP/gRPC exporter across signals.
///
/// NOTE: This is a temporary measure and this type will be overhauled as we migrate to gRPC Swift v2.
protocol OTLPGRPCClient<Request, Response, Interceptors>: GRPCClient {
    associatedtype Request
    associatedtype Response
    associatedtype Interceptors
    func export(_ request: Request, callOptions: CallOptions?) async throws -> Response

    init(
        channel: GRPCChannel,
        defaultCallOptions: CallOptions,
        interceptors: Interceptors?
    )
}

extension Opentelemetry_Proto_Collector_Trace_V1_TraceServiceAsyncClient: OTLPGRPCClient {}
extension Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceAsyncClient: OTLPGRPCClient {}
extension Opentelemetry_Proto_Collector_Logs_V1_LogsServiceAsyncClient: OTLPGRPCClient {}

final class OTLPGRPCExporter<Client: OTLPGRPCClient>: Sendable where Client: Sendable {
    private let connection: ClientConnection
    private let client: Client
    private let logger = Logger(label: "OTLPGRPCExporter")

    init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        let group = MultiThreadedEventLoopGroup.singleton

        guard configuration.protocol == .grpc else {
            throw OTLPGRPCExporterError.invalidProtocol
        }

        guard
            let endpointComponents = URLComponents(string: configuration.endpoint),
            let host = endpointComponents.host,
            let port = endpointComponents.port
        else {
            throw OTLPGRPCExporterError.invalidEndpoint(configuration.endpoint)
        }

        /// > A scheme of https indicates a secure connection and takes precedence over the insecure configuration
        /// > setting. A scheme of http indicates an insecure connection and takes precedence over the insecure
        /// > configuration setting. If the gRPC client implementation does not support an endpoint with a scheme of
        /// > http or https then the endpoint SHOULD be transformed to the most sensible format for that implementation.
        /// > —— source: https://opentelemetry.io/docs/specs/otel/protocol/exporter/
        let insecure = switch endpointComponents.scheme {
        case "https": false
        case "http": true
        default: configuration.insecure
        }

        if insecure {
            self.connection = ClientConnection.insecure(group: group).connect(host: host, port: port)
        } else {
            let builder = ClientConnection.usingTLSBackedByNIOSSL(on: group)
            // TLS
            if let certPath = configuration.certificateFilePath {
                builder.withTLS(trustRoots: .file(certPath))
            } else {
                builder.withTLS(trustRoots: .default)
            }
            // mTLS
            switch (configuration.clientCertificateFilePath, configuration.clientKeyFilePath) {
            case (.none, .none):
                break
            case (.some, .none), (.none, .some):
                throw OTLPGRPCExporterError.partialMTLSdConfiguration
            case (.some(let clientCertPath), .some(let clientKeyPath)):
                try builder
                    .withTLS(certificateChain: NIOSSLCertificate.fromPEMFile(clientCertPath))
                    .withTLS(privateKey: NIOSSLPrivateKey(file: clientKeyPath, format: .pem))
            }
            self.connection = builder.connect(host: host, port: port)
        }

        var headers = HPACKHeaders(configuration.headers)
        if !headers.isEmpty {
            logger.trace("Configured custom request headers.", metadata: [
                "keys": .array(headers.map { .string($0.name) }),
            ])
        }
        headers.replaceOrAdd(name: "User-Agent", value: "OTel-OTLP-Exporter-Swift/\(OTelLibrary.version)")

        self.client = Client(
            channel: connection,
            defaultCallOptions: .init(customMetadata: headers, logger: ._otelDisabled),
            interceptors: nil
        )
    }

    func run() async throws {
        // Nothing to do right now, but will be important for gRPC v2.
    }

    func export(_ request: Client.Request) async throws -> Client.Response {
        if case .shutdown = connection.connectivity.state {
            logger.error("Attempted to export while already being shut down.")
            throw OTLPGRPCExporterError.exporterAlreadyShutDown
        }
        return try await client.export(request, callOptions: nil)
    }

    func forceFlush() async throws {
        // This exporter is a "push exporter" and so the OTel spec says that force flush should do nothing.
    }

    func shutdown() async {
        let promise = connection.eventLoop.makePromise(of: Void.self)
        connection.closeGracefully(deadline: .now() + .milliseconds(500), promise: promise)
        try? await promise.futureResult.get()
    }
}

enum OTLPGRPCExporterError: Swift.Error {
    case invalidEndpoint(String)
    case partialMTLSdConfiguration
    case exporterAlreadyShutDown
    case invalidProtocol
}

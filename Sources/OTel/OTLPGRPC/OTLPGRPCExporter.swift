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
import GRPCCore
import OTLPGRPC
import OTLPCore
import GRPCNIOTransportHTTP2
import Logging

/// Unifying protocol for shared OTLP/gRPC exporter across signals.
@available(gRPCSwift, *)
protocol OTLPGRPCClient<Transport, Request, Response> where Response: Sendable, Transport: ClientTransport {
    associatedtype Transport
    associatedtype Request
    associatedtype Response

    init(wrapping client: GRPCClient<Transport>)

    func export<Result>(
        _ message: Request,
        metadata: Metadata,
        options: CallOptions,
        onResponse handleResponse: @Sendable @escaping (ClientResponse<Response>) async throws -> Result
    ) async throws -> Result where Result: Sendable
}

@available(gRPCSwift, *)
extension Opentelemetry_Proto_Collector_Logs_V1_LogsService.Client: OTLPGRPCClient {}
@available(gRPCSwift, *)
extension Opentelemetry_Proto_Collector_Metrics_V1_MetricsService.Client: OTLPGRPCClient {}
@available(gRPCSwift, *)
extension Opentelemetry_Proto_Collector_Trace_V1_TraceService.Client: OTLPGRPCClient {}

@available(gRPCSwift, *)
final class OTLPGRPCExporter<Client: OTLPGRPCClient>: Sendable where Client: Sendable, Client.Transport == HTTP2ClientTransport.Posix {
    private let logger: Logger
    private let underlyingClient: GRPCClient<Client.Transport>
    private let client: Client
    private let metadata: Metadata
    private let callOptions: CallOptions

    init(configuration: OTel.Configuration.OTLPExporterConfiguration, logger: Logger) throws {
        guard configuration.protocol == .grpc else {
            throw OTLPGRPCExporterError.invalidProtocol
        }
        self.logger = logger.withMetadata(component: "OTLPGRPCExporter")
        self.underlyingClient = try GRPCClient(transport: HTTP2ClientTransport.Posix(configuration))
        self.client = Client(wrapping: underlyingClient)
        self.metadata = Metadata(configuration)
        self.callOptions = CallOptions(configuration)
    }

    func run() async throws {
        try await underlyingClient.runConnections()
    }

    func export(_ request: Client.Request) async throws -> Client.Response {
        do {
            return try await client.export(request, metadata: metadata, options: callOptions) { response in
                try response.message
            }
        } catch let error as GRPCCore.RuntimeError where error.code == .clientIsStopped {
            throw OTLPGRPCExporterError.exporterAlreadyShutDown
        } catch {
            throw error
        }
    }

    func forceFlush() async throws {
        // This exporter is a "push exporter" and so the OTel spec says that force flush should do nothing.
    }

    func shutdown() async {
        underlyingClient.beginGracefulShutdown()
    }
}

@available(gRPCSwift, *)
enum OTLPGRPCExporterError: Swift.Error {
    case invalidEndpoint(String)
    case partialMTLSdConfiguration
    case exporterAlreadyShutDown
    case invalidProtocol
}

@available(gRPCSwift, *)
extension HTTP2ClientTransport.Posix.Config {
    init(_ configuration: OTel.Configuration.OTLPExporterConfiguration) {
        self = .defaults
        switch configuration.compression.backing {
        case .gzip: self.compression = .init(algorithm: .gzip, enabledAlgorithms: [.gzip])
        case .none: self.compression = .init(algorithm: .none, enabledAlgorithms: [.none])
        }
    }
}

@available(gRPCSwift, *)
extension CallOptions {
    init(_ configuration: OTel.Configuration.OTLPExporterConfiguration) {
        self = .defaults
        self.timeout = configuration.timeout
        // TODO: we're setting compression here and in the transport config; do we need both?
        self.compression = switch configuration.compression.backing {
        case .gzip: .gzip
        case .none: CompressionAlgorithm.none
        }
        // TODO: retry/backoff policy here
    }
}

@available(gRPCSwift, *)
extension HTTP2ClientTransport.Posix {
    init(_ configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        guard
            let endpointComponents = URLComponents(string: configuration.grpcEndpoint),
            let host = endpointComponents.host,
            let port = endpointComponents.port
        else {
            throw OTLPGRPCExporterError.invalidEndpoint(configuration.grpcEndpoint)
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

        let security: HTTP2ClientTransport.Posix.TransportSecurity
        if insecure {
            security = .plaintext
        } else {
            // TLS
            var tlsConfig = HTTP2ClientTransport.Posix.TransportSecurity.TLS.defaults
            if let certPath = configuration.certificateFilePath {
                tlsConfig.trustRoots = .certificates([.file(path: certPath, format: .pem)])
            }
            // mTLS
            switch (configuration.clientCertificateFilePath, configuration.clientKeyFilePath) {
            case (.none, .none):
                break
            case (.some, .none), (.none, .some):
                throw OTLPGRPCExporterError.partialMTLSdConfiguration
            case (.some(let clientCertPath), .some(let clientKeyPath)):
                tlsConfig.certificateChain = [.file(path: clientCertPath, format: .pem)]
                tlsConfig.privateKey = .file(path: clientKeyPath, format: .pem)
            }
            security = .tls(tlsConfig)
        }

        try self.init(
            target: .dns(host: host, port: port),
            transportSecurity: security,
            config: Config(configuration)
        )
    }
}

@available(gRPCSwift, *)
extension Metadata {
    init(_ configuration: OTel.Configuration.OTLPExporterConfiguration) {
        self.init()
        self.reserveCapacity(configuration.headers.count)
        for (key, value) in configuration.headers {
            self.addString(value, forKey: key)
        }
        self.replaceOrAddString("OTel-OTLP-Exporter-Swift/\(OTelLibrary.version)", forKey: "User-Agent")
    }
}

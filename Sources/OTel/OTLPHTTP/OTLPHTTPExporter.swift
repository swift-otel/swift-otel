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

#if !OTLPHTTP
// Empty when above trait(s) are disabled.
#else
import AsyncHTTPClient
import Logging
import NIOFoundationCompat
import NIOHTTP1
import NIOSSL
import ServiceLifecycle
import SwiftProtobuf

import struct Foundation.Data
import class Foundation.FileManager
import struct Foundation.URL

final class OTLPHTTPExporter<Request: Message, Response: Message>: Sendable {
    let configuration: OTel.Configuration.OTLPExporterConfiguration
    let httpClient: HTTPClient

    init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        self.configuration = configuration
        self.httpClient = try HTTPClient(configuration: configuration)
    }

    deinit {
        // This is a backstop measure where we shut down the HTTP client.
        //
        // The usual flow for this type is an explicit shutdown, which is handled by the object that holds the exporter.
        //
        // In some narrow scenarios, this type will have been created but the holding type not successfully created or
        // started, e.g. when there is a misconfiguraiton. In these scenarios, the user should be presented with a clear
        // error that they can debug. Having the application crash because HTTP client inside the exporter was not
        // shutdown will worsen the experience.
        try? self.httpClient.syncShutdown()
    }

    func run() async throws {
        // No background work needed, but we'll keep the run method running until its cancelled.
        try await gracefulShutdown()
    }

    func send(_ proto: Request) async throws -> Response {
        // https://opentelemetry.io/docs/specs/otlp/#otlphttp-request
        var request = HTTPClientRequest(url: self.configuration.endpoint)
        request.method = .POST
        for (name, value) in configuration.headers {
            request.headers.add(name: name, value: value)
        }
        switch self.configuration.protocol.backing {
        case .httpProtobuf:
            // https://opentelemetry.io/docs/specs/otlp/#binary-protobuf-encoding
            request.body = try .bytes(proto.serializedData())
            request.headers.replaceOrAdd(name: "Content-Type", value: "application/x-protobuf")
        case .httpJSON:
            // https://opentelemetry.io/docs/specs/otlp/#json-protobuf-encoding
            // TODO: Double check the spec for any missing JSON transformation and whether Swift Protobuf supports them.
            var encodingOptions = JSONEncodingOptions()
            encodingOptions.alwaysPrintInt64sAsNumbers = false
            encodingOptions.alwaysPrintEnumsAsInts = true
            encodingOptions.preserveProtoFieldNames = false
            request.body = try .bytes(proto.jsonUTF8Data(options: encodingOptions))
            request.headers.replaceOrAdd(name: "Content-Type", value: "application/json")
        case .grpc:
            preconditionFailure("unreachable")
        }

        // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#user-agent
        request.headers.replaceOrAdd(name: "User-Agent", value: "OTel-OTLP-Exporter-Swift/\(OTelLibrary.version)")
        // https://opentelemetry.io/docs/specs/otlp/#otlphttp-connection
        request.headers.replaceOrAdd(name: "Connection", value: "keep-alive")

        // https://opentelemetry.io/docs/specs/otlp/#otlphttp-response
        let response = try await self.httpClient.execute(request, timeout: .init(self.configuration.timeout))
        switch response.status {
        case .ok:
            break
        case .tooManyRequests, .badGateway, .serviceUnavailable, .gatewayTimeout:
            // https://opentelemetry.io/docs/specs/otlp/#retryable-response-codes
            // https://opentelemetry.io/docs/specs/otlp/#otlphttp-throttling
            // TODO: Retry logic
            throw OTLPHTTPExporterError.requestFailedWithRetryableError
        default:
            // https://opentelemetry.io/docs/specs/otlp/#failures
            // TODO: Apparently failures include Protobuf-encoded GRPC Status -- we could try and include it here.
            throw OTLPHTTPExporterError.requestFailed(response.status)
        }

        // https://opentelemetry.io/docs/specs/otlp/#full-success-1
        let body = try await response.body.collect(upTo: 2 * 1024 * 1024)
        let responseMessage = switch response.headers.first(name: "Content-Type") {
        case "application/x-protobuf":
            // TODO: can we avoid the Data here?
            try Response(serializedBytes: Data(buffer: body))
        case "application/json":
            // TODO: can we avoid the Data here?
            try Response(jsonUTF8Data: Data(buffer: body))
        case .some(let content):
            throw OTLPHTTPExporterError.responseHasUnsupportedContentType(content)
        case .none:
            throw OTLPHTTPExporterError.responseHasMissingContentType
        }
        return responseMessage
    }

    func forceFlush() async throws {
        // This exporter is a "push exporter" and so the OTel spec says that force flush should do nothing.
    }

    func shutdown() async {
        try? await self.httpClient.shutdown()
    }
}

enum OTLPHTTPExporterError: Swift.Error {
    case responseHasUnsupportedContentType(String)
    case responseHasMissingContentType
    case requestFailed(HTTPResponseStatus)
    case requestFailedWithRetryableError
    case partialMTLSdConfiguration
    case serverCertificateFileNotFound(String)
    case clientCertificateFileNotFound(String)
    case clientKeyFileNotFound(String)
}

extension HTTPClient {
    fileprivate convenience init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        try self.init(
            eventLoopGroup: .singletonMultiThreadedEventLoopGroup,
            configuration: .init(configuration: configuration)
        )
    }
}

extension HTTPClient.Configuration {
    fileprivate init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        self = .singletonConfiguration
        self.timeout = .init(write: .init(configuration.timeout))
        /// Here we determine the scheme based only on the endpoint, and ignore the `insecure` option.
        ///
        /// > This option only applies to OTLP/gRPC when an endpoint is provided without the http or https
        /// > scheme - OTLP/HTTP always uses the scheme provided for the endpoint.
        /// — source: https://opentelemetry.io/docs/specs/otel/protocol/exporter/#configuration-options
        if URL(string: configuration.endpoint)?.scheme != "https" {
            self.tlsConfiguration = nil
        } else {
            // TLS
            if let certPath = configuration.certificateFilePath {
                guard FileManager.default.fileExists(atPath: certPath) else {
                    throw OTLPHTTPExporterError.serverCertificateFileNotFound(certPath)
                }
                self.tlsConfiguration?.trustRoots = .file(certPath)
            }
            // mTLS
            switch (configuration.clientCertificateFilePath, configuration.clientKeyFilePath) {
            case (.none, .none):
                break
            case (.some, .none), (.none, .some):
                throw OTLPHTTPExporterError.partialMTLSdConfiguration
            case (.some(let clientCertPath), .some(let clientKeyPath)):
                guard FileManager.default.fileExists(atPath: clientCertPath) else {
                    throw OTLPHTTPExporterError.clientCertificateFileNotFound(clientCertPath)
                }
                guard FileManager.default.fileExists(atPath: clientKeyPath) else {
                    throw OTLPHTTPExporterError.clientKeyFileNotFound(clientKeyPath)
                }
                let clientCerts = try NIOSSLCertificate.fromPEMFile(clientCertPath).map { cert in
                    NIOSSLCertificateSource.certificate(cert)
                }
                self.tlsConfiguration?.certificateChain = clientCerts
                self.tlsConfiguration?.privateKey = try .privateKey(.init(file: clientKeyPath, format: .pem))
            }
        }
    }
}
#endif

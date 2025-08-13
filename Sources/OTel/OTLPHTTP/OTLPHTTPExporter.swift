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

#if canImport(FoundationEssentials)
import class FoundationEssentials.FileManager
import struct FoundationEssentials.URL
#else
import class Foundation.FileManager
import struct Foundation.URL
#endif
import struct NIOCore.ByteBuffer
import struct NIOCore.TimeAmount

final class OTLPHTTPExporter<Request: Message, Response: Message>: Sendable {
    private let logger: Logger
    let configuration: OTel.Configuration.OTLPExporterConfiguration
    let httpClient: HTTPClient

    init(configuration: OTel.Configuration.OTLPExporterConfiguration, logger: Logger) throws {
        self.logger = logger
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
        let response = try await self.httpClient.execute(
            request,
            timeout: .init(self.configuration.timeout),
            logger: self.logger,
            retryPolicy: .otel
        )

        guard response.status == .ok else {
            // https://opentelemetry.io/docs/specs/otlp/#failures
            // TODO: Apparently failures include Protobuf-encoded GRPC Status -- we could try and include it here.
            throw OTLPHTTPExporterError.requestFailed(response.status)
        }

        // https://opentelemetry.io/docs/specs/otlp/#full-success-1
        let body = try await response.body.collect(upTo: 2 * 1024 * 1024)
        let responseMessage = switch response.headers.first(name: "Content-Type") {
        case "application/x-protobuf":
            try Response(serializedBytes: ByteBufferWrapper(backing: body))
        case "application/json":
            try Response(jsonUTF8Bytes: ByteBufferWrapper(backing: body))
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

extension HTTPClient {
    struct RetryPolicy: Sendable {
        private(set) var attempts: Int
        private(set) var maxAttempts: Int
        private let baseDelay: Duration
        private let maxDelay: Duration
        private let jitter: Double
        private(set) var policy: @Sendable (HTTPClientResponse) -> PolicyDecision

        init(
            maxAttempts: Int = 10,
            baseDelay: Duration = .seconds(1),
            maxDelay: Duration = .seconds(60),
            jitter: Double = 0.1,
            policy: @escaping @Sendable (HTTPClientResponse) -> PolicyDecision
        ) {
            self.attempts = 0
            self.maxAttempts = maxAttempts
            self.baseDelay = baseDelay
            self.maxDelay = maxDelay
            self.jitter = jitter
            self.policy = policy
        }

        enum PolicyDecision {
            case doNotRetry
            case retryWithBackoff
            case retryWithSpecificBackoff(Duration)
        }

        enum RetryDecision: Equatable {
            case doNotRetry
            case retryAfter(Duration)
        }

        mutating func shouldRetry(response: HTTPClientResponse) -> RetryDecision {
            attempts += 1
            if attempts >= maxAttempts { return .doNotRetry }
            switch policy(response) {
            case .doNotRetry: return .doNotRetry
            case .retryWithBackoff:
                let exponentialDelay = baseDelay * (2 << (attempts - 2))
                let cappedDelay = min(exponentialDelay, maxDelay)
                let jitterAmount = cappedDelay * jitter * Double.random(in: -1 ... 1)
                let delay = max(Duration.zero, cappedDelay + jitterAmount)
                return .retryAfter(delay)
            case .retryWithSpecificBackoff(let delay):
                return .retryAfter(delay)
            }
        }
    }
}

extension HTTPClient.RetryPolicy {
    /// A policy for use with the OTLP/HTTP exporter, following guidance from the spec.
    ///
    /// - See: [](https://opentelemetry.io/docs/specs/otlp/#retryable-response-codes)
    /// - See: [](https://opentelemetry.io/docs/specs/otlp/#otlphttp-throttling)
    static let otel = Self { response in
        switch response.status {
        case .tooManyRequests, .badGateway, .serviceUnavailable, .gatewayTimeout:
            if let specificBackoff = response.headers["Retry-After"].last.flatMap(Int.init) {
                .retryWithSpecificBackoff(.seconds(specificBackoff))
            } else {
                .retryWithBackoff
            }
        default: .doNotRetry
        }
    }
}

extension HTTPClient {
    func execute<Clock: _Concurrency.Clock>(
        _ request: HTTPClientRequest,
        timeout: TimeAmount,
        logger: Logger? = nil,
        clock: Clock = .continuous,
        retryPolicy: RetryPolicy
    ) async throws -> HTTPClientResponse where Clock.Duration == Duration {
        if var logger {
            logger[metadataKey: "attempts"] = "\(retryPolicy.attempts)"
            logger[metadataKey: "max_attempts"] = "\(retryPolicy.maxAttempts)"
        }
        logger?.debug("Making request.")
        var retryPolicy = retryPolicy
        let response = try await self.execute(request, timeout: timeout, logger: logger)
        switch retryPolicy.shouldRetry(response: response) {
        case .doNotRetry:
            logger?.debug("Returning response.", metadata: ["status_code": "\(response.status.code)"])
            return response
        case .retryAfter(let delay):
            logger?.debug("Retrying request.", metadata: ["status_code": "\(response.status.code)"])
            try await _Concurrency.Task.sleep(for: delay, clock: clock)
            return try await self.execute(
                request,
                timeout: timeout,
                logger: logger,
                clock: clock,
                retryPolicy: retryPolicy
            )
        }
    }
}

/// This internal type allows us to conform to `SwiftProtobufContiguousBytes` and avoid a copy on the response.
fileprivate struct ByteBufferWrapper: SwiftProtobufContiguousBytes {
    var backing: ByteBuffer

    init(backing: ByteBuffer) {
        self.backing = backing
    }

    init(_ sequence: some Sequence<UInt8>) {
        self.backing = ByteBuffer(bytes: sequence)
    }

    init(repeating: UInt8, count: Int) {
        self.backing = ByteBuffer(repeating: repeating, count: count)
    }

    var count: Int { self.backing.readableBytes }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try self.backing.withUnsafeReadableBytes { try body($0) }
    }

    mutating func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R {
        try self.backing.withUnsafeMutableReadableBytes { try body($0) }
    }
}
#endif

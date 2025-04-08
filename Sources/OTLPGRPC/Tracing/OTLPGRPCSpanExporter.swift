//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2024 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Foundation.URL
import GRPCCore
import GRPCNIOTransportHTTP2
import Logging
import NIO
import NIOHPACK
import NIOSSL
import OTel
import OTLPCore
import Tracing

/// A span exporter emitting span batches to an OTel collector via gRPC.
public final class OTLPGRPCSpanExporter: OTelSpanExporter {
    private let configuration: OTLPGRPCSpanExporterConfiguration
    private let client: Opentelemetry_Proto_Collector_Trace_V1_TraceService.Client<HTTP2ClientTransport.Posix>
    private let grpcClient: GRPCClient<HTTP2ClientTransport.Posix>
    private let grpcClientTask: Task<Void, any Error>
    private let logger = Logger(label: String(describing: OTLPGRPCSpanExporter.self))

    /// Create an OTLP gRPC span exporter.
    ///
    /// - Parameters:
    ///   - configuration: The exporters configuration.
    ///   - group: The NIO event loop group to run the exporter in.
    ///   - requestLogger: Logs info about the underlying gRPC requests. Defaults to disabled, i.e. not emitting any logs.
    ///   - backgroundActivityLogger: Logs info about the underlying gRPC connection. Defaults to disabled, i.e. not emitting any logs.
    public convenience init(
        configuration: OTLPGRPCSpanExporterConfiguration,
        group: any EventLoopGroup = MultiThreadedEventLoopGroup.singleton,
        requestLogger: Logger = ._otelDisabled,
        backgroundActivityLogger: Logger = ._otelDisabled
    ) {
        self.init(
            configuration: configuration,
            group: group,
            requestLogger: requestLogger,
            backgroundActivityLogger: backgroundActivityLogger,
            trustRoots: .systemDefault
        )
    }

    init(
        configuration: OTLPGRPCSpanExporterConfiguration,
        group: any EventLoopGroup,
        requestLogger: Logger,
        backgroundActivityLogger: Logger,
        trustRoots: TLSConfig.TrustRootsSource
    ) {
        self.configuration = configuration

        if configuration.endpoint.isInsecure {
            logger.debug("Using insecure connection.", metadata: [
                "host": "\(configuration.endpoint.host)",
                "port": "\(configuration.endpoint.port)",
            ])
        } else {
            logger.debug("Using secure connection.", metadata: [
                "host": "\(configuration.endpoint.host)",
                "port": "\(configuration.endpoint.port)",
            ])
            // TODO: Support OTEL_EXPORTER_OTLP_CERTIFICATE
            // TODO: Support OTEL_EXPORTER_OTLP_CLIENT_KEY
            // TODO: Support OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE
        }

        if !configuration.metadata.isEmpty {
            logger.trace("Configured custom request headers.", metadata: [
                "keys": .array(configuration.metadata.map { "\($0.key)" }),
            ])
        }

        let transport: HTTP2ClientTransport.Posix
        do {
            transport = try HTTP2ClientTransport.Posix(
                target: .ipv6(host: configuration.endpoint.host, port: configuration.endpoint.port),
                transportSecurity: configuration.endpoint.isInsecure ? .plaintext : .tls(configure: { config in
                    config.trustRoots = trustRoots
                }),
                eventLoopGroup: group
            )
        } catch {
            preconditionFailure("Failed to create HTTP2ClientTransport: \(error)")
        }

        let grpcClient = GRPCClient(transport: transport)
        self.grpcClient = grpcClient
        client = Opentelemetry_Proto_Collector_Trace_V1_TraceService.Client(
            wrapping: GRPCClient(transport: transport)
        )
        grpcClientTask = Task {
            try await grpcClient.runConnections()
        }
    }

    public func export(_ batch: some Collection<OTelFinishedSpan>) async throws {
        guard let firstSpanResource = batch.first?.resource else { return }

        let request = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with { request in
            request.resourceSpans = [
                .with { resourceSpans in
                    resourceSpans.resource = .with { resource in
                        resource.attributes = .init(firstSpanResource.attributes)
                    }

                    resourceSpans.scopeSpans = [
                        .with { scopeSpans in
                            scopeSpans.scope = .with { scope in
                                scope.name = "swift-otel"
                                scope.version = OTelLibrary.version
                            }
                            scopeSpans.spans = batch.map(Opentelemetry_Proto_Trace_V1_Span.init)
                        },
                    ]
                },
            ]
        }

        _ = try await client.export(request, metadata: configuration.metadata)
    }

    /// ``OTLPGRPCSpanExporter`` sends batches of spans as soon as they are received, so this method is a no-op.
    public func forceFlush() async throws {}

    public func shutdown() async {
        // TODO: How do we replicate a graceful shut down timeout
        grpcClient.beginGracefulShutdown()
        try? await grpcClientTask.value
    }
}

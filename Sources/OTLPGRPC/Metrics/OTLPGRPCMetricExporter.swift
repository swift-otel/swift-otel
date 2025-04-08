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

import GRPCCore
import GRPCNIOTransportHTTP2
import Logging
import NIO
import NIOHPACK
import NIOSSL
import OTel
import OTLPCore

/// Exports metrics to an OTel collector using OTLP/gRPC.
public final class OTLPGRPCMetricExporter: OTelMetricExporter {
    private let configuration: OTLPGRPCMetricExporterConfiguration
    private let client: Opentelemetry_Proto_Collector_Metrics_V1_MetricsService.Client<HTTP2ClientTransport.Posix>
    private let grpcClient: GRPCClient<HTTP2ClientTransport.Posix>
    private let grpcClientTask: Task<Void, any Error>
    private let logger = Logger(label: String(describing: OTLPGRPCMetricExporter.self))

    public convenience init(
        configuration: OTLPGRPCMetricExporterConfiguration,
        group: any EventLoopGroup = MultiThreadedEventLoopGroup.singleton,
        requestLogger: Logger = ._otelDisabled,
        backgroundActivityLogger: Logger = ._otelDisabled
    ) {
        self.init(
            configuration: configuration,
            group: group,
            requestLogger: requestLogger,
            backgroundActivityLogger: backgroundActivityLogger,
            trustRoots: .default
        )
    }

    init(
        configuration: OTLPGRPCMetricExporterConfiguration,
        group: any EventLoopGroup,
        requestLogger: Logger,
        backgroundActivityLogger: Logger,
        trustRoots: NIOSSLTrustRoots
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

        var headers = configuration.headers
        if !headers.isEmpty {
            logger.trace("Configured custom request headers.", metadata: [
                "keys": .array(headers.map { "\($0.name)" }),
            ])
        }
        headers.replaceOrAdd(name: "user-agent", value: "OTel-OTLP-Exporter-Swift/\(OTelLibrary.version)")

        let transport: HTTP2ClientTransport.Posix
        do {
            transport = try HTTP2ClientTransport.Posix(
                target: .dns(host: configuration.endpoint.host, port: configuration.endpoint.port),
                transportSecurity: configuration.endpoint.isInsecure ? .plaintext : .tls,
                eventLoopGroup: group
            )
        } catch {
            preconditionFailure("Failed to create HTTP2ClientTransport: \(error)")
        }

        let grpcClient = GRPCClient(transport: transport)
        self.grpcClient = grpcClient
        client = Opentelemetry_Proto_Collector_Metrics_V1_MetricsService.Client(
            wrapping: GRPCClient(transport: transport)
        )
        grpcClientTask = Task {
            try await grpcClient.runConnections()
        }
    }

    public func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws {
        let request = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with { request in
            request.resourceMetrics = batch.map(Opentelemetry_Proto_Metrics_V1_ResourceMetrics.init)
        }

        _ = try await client.export(request)
    }

    public func forceFlush() async throws {
        // This exporter is a "push exporter" and so the OTel spec says that force flush should do nothing.
    }

    public func shutdown() async {
        // TODO: How do we replicate a graceful shut down timeout
        grpcClient.beginGracefulShutdown()
        try? await grpcClientTask.value
    }
}

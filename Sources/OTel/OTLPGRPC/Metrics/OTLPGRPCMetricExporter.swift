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

#if !OTLPGRPC
// Empty when above trait(s) are disabled.
#else
import GRPCNIOTransportHTTP2
import Logging

/// A metrics exporter emitting metric batches to an OTel collector via gRPC.
@available(gRPCSwift, *)
final class OTLPGRPCMetricExporter: OTelMetricExporter {
    typealias Client = Opentelemetry_Proto_Collector_Metrics_V1_MetricsService.Client<HTTP2ClientTransport.Posix>
    private let client: OTLPGRPCExporter<Client>

    init(configuration: OTel.Configuration.OTLPExporterConfiguration, logger: Logger) throws {
        client = try OTLPGRPCExporter(configuration: configuration, logger: logger)
    }

    func run() async throws {
        try await client.run()
    }

    func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws {
        let request = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with { request in
            request.resourceMetrics = batch.map(Opentelemetry_Proto_Metrics_V1_ResourceMetrics.init)
        }
        _ = try await client.export(request)
    }

    func forceFlush() async throws {
        try await client.forceFlush()
    }

    func shutdown() async {
        await client.shutdown()
    }
}
#endif

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
import Logging

final class OTLPHTTPMetricExporter: OTelMetricExporter {
    typealias Request = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest
    typealias Response = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse
    let exporter: OTLPHTTPExporter<Request, Response>
    private let logger: Logger

    init(configuration: OTel.Configuration.OTLPExporterConfiguration, logger: Logger) throws {
        self.logger = logger.withMetadata(component: "OTLPHTTPMetricExporter")
        var configuration = configuration
        configuration.endpoint = configuration.metricsHTTPEndpoint
        exporter = try OTLPHTTPExporter(configuration: configuration)
    }

    func run() async throws {}

    func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws {
        guard batch.contains(where: { $0.scopeMetrics.contains(where: { !$0.metrics.isEmpty }) }) else { return }
        let proto = Request.with { request in
            request.resourceMetrics = batch.map(Opentelemetry_Proto_Metrics_V1_ResourceMetrics.init)
        }
        let response = try await exporter.send(proto)
        if response.hasPartialSuccess {
            // https://opentelemetry.io/docs/specs/otlp/#partial-success-1
            logger.warning("Partial success", metadata: [
                "message": "\(response.partialSuccess.errorMessage)",
                "rejected_data_points": "\(response.partialSuccess.rejectedDataPoints)",
            ])
        }
    }

    func forceFlush() async throws {
        try await exporter.forceFlush()
    }

    func shutdown() async {
        await exporter.shutdown()
    }
}
#endif

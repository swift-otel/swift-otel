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
package import OTelCore
import OTLPCore

package final class OTLPHTTPMetricExporter: OTelMetricExporter {
    typealias Request = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest
    typealias Response = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse
    let exporter: OTLPHTTPExporter<Request, Response>
    private let logger = Logger(label: String(describing: OTLPHTTPMetricExporter.self))

    package init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        exporter = try OTLPHTTPExporter(configuration: configuration)
    }

    package func run() async throws {}

    package func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws {
        let proto = Request.with { request in
            request.resourceMetrics = batch.map(Opentelemetry_Proto_Metrics_V1_ResourceMetrics.init)
        }
        let response = try await exporter.send(proto)
        if response.hasPartialSuccess {
            // https://opentelemetry.io/docs/specs/otlp/#partial-success-1
            logger.warning("Partial success", metadata: ["message": .string(response.partialSuccess.errorMessage)])
        }
    }

    package func forceFlush() async throws {
        try await exporter.forceFlush()
    }

    package func shutdown() async {
        await exporter.shutdown()
    }
}

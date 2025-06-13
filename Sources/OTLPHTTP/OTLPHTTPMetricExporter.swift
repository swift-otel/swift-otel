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

import OTelCore
import OTLPCore

package final class OTLPHTTPMetricExporter: OTelMetricExporter {
    let exporter: OTLPHTTPExporter

    package init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        exporter = try OTLPHTTPExporter(configuration: configuration)
    }

    package func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws {
        let proto = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with { request in
            request.resourceMetrics = batch.map(Opentelemetry_Proto_Metrics_V1_ResourceMetrics.init)
        }
        try await exporter.send(proto)
    }

    package func forceFlush() async throws {
        try await exporter.forceFlush()
    }

    package func shutdown() async {
        await exporter.shutdown()
    }
}

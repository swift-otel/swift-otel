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

package final class OTLPHTTPSpanExporter: OTelSpanExporter {
    let exporter: OTLPHTTPExporter

    package init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        exporter = try OTLPHTTPExporter(configuration: configuration)
    }

    package func export(_ batch: some Collection<OTelCore.OTelFinishedSpan> & Sendable) async throws {
        let request = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with { request in
            request.resourceSpans = [Opentelemetry_Proto_Trace_V1_ResourceSpans(batch)]
        }
        try await exporter.send(request)
    }

    package func forceFlush() async throws {
        try await exporter.forceFlush()
    }

    package func shutdown() async {
        await exporter.shutdown()
    }
}

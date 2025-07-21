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

package import Logging
package import OTelCore
import OTLPCore

package final class OTLPHTTPSpanExporter: OTelSpanExporter {
    typealias Request = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest
    typealias Response = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse
    let exporter: OTLPHTTPExporter<Request, Response>
    private let logger: Logger

    package init(configuration: OTel.Configuration.OTLPExporterConfiguration, logger: Logger) throws {
        self.logger = logger
        var configuration = configuration
        configuration.endpoint = configuration.tracesHTTPEndpoint
        exporter = try OTLPHTTPExporter(configuration: configuration)
    }

    package func run() async throws {}

    package func export(_ batch: some Collection<OTelFinishedSpan> & Sendable) async throws {
        let proto = Request.with { request in
            request.resourceSpans = [Opentelemetry_Proto_Trace_V1_ResourceSpans(batch)]
        }
        let response = try await exporter.send(proto)
        if response.hasPartialSuccess {
            // https://opentelemetry.io/docs/specs/otlp/#partial-success-1
            logger.warning("Partial success", metadata: [
                "message": "\(response.partialSuccess.errorMessage)",
                "rejected_spans": "\(response.partialSuccess.rejectedSpans)",
            ])
        }
    }

    package func forceFlush() async throws {
        try await exporter.forceFlush()
    }

    package func shutdown() async {
        await exporter.shutdown()
    }
}

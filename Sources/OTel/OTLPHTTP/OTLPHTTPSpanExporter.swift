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

final class OTLPHTTPSpanExporter: OTelSpanExporter {
    typealias Request = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest
    typealias Response = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse
    let exporter: OTLPHTTPExporter<Request, Response>
    private let logger: Logger

    init(configuration: OTel.Configuration.OTLPExporterConfiguration, logger: Logger) throws {
        self.logger = logger.withMetadata(component: "OTLPHTTPSpanExporter")
        var configuration = configuration
        configuration.endpoint = configuration.tracesHTTPEndpoint
        exporter = try OTLPHTTPExporter(configuration: configuration)
    }

    func run() async throws {}

    func export(_ batch: some Collection<OTelFinishedSpan> & Sendable) async throws {
        guard !batch.isEmpty else { return }
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

    func forceFlush() async throws {
        try await exporter.forceFlush()
    }

    func shutdown() async {
        await exporter.shutdown()
    }
}
#endif

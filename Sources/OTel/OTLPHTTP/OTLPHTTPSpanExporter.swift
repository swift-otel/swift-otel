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
        exporter = try OTLPHTTPExporter(configuration: configuration, logger: logger)
    }

    func run() async throws {
        try await exporter.run()
    }

    func export(_ batch: some Collection<OTelFinishedSpan> & Sendable) async throws {
        guard !batch.isEmpty else { return }
        let proto = Request.with { request in
            request.resourceSpans = [Opentelemetry_Proto_Trace_V1_ResourceSpans(batch)]
        }
        let response = try await exporter.send(proto)
        if response.hasPartialSuccess {
            // https://opentelemetry.io/docs/specs/otlp/#partial-success-1
            /// > If the request is only partially accepted ... the server MUST initialize the `partial_success` field
            /// > ... and it MUST set the respective `rejected_spans`, `rejected_data_points`, `rejected_log_records`
            /// > or `rejected_profiles` field with the number of spans/data points/log records it rejected.
            /// >
            /// > The server SHOULD populate the `error_message` field ...
            /// >
            /// > Servers MAY also use the `partial_success` field to convey warnings/suggestions to clients even when
            /// > it fully accepts the request. In such cases, the `rejected_<signal>` field MUST have a value of `0`,
            /// > and the `error_message` field MUST be non-empty.
            /// - source: https://opentelemetry.io/docs/specs/otlp/#partial-success-1
            ///
            /// The OTel Collector is known to return a non-compliant response, where it doesn't drop any telemetry, but
            /// the protobuf message has the `partial_success` field set on the wire with a rejected count of `0` and an
            /// empty `error_message`.
            ///
            /// https://github.com/open-telemetry/opentelemetry-collector-contrib/discussions/17833
            ///
            /// Since this is a useless response and ostensibly all is fine (the rejected count is 0 and there's no
            /// message), we'll log that at debug instead of warning.
            let logLevel: Logger.Level
            if response.partialSuccess.rejectedSpans == 0, response.partialSuccess.errorMessage.isEmpty {
                logLevel = .debug
            } else {
                logLevel = .warning
            }
            logger.log(level: logLevel, "Partial success", metadata: [
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

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

package final class OTLPHTTPLogRecordExporter: OTelLogRecordExporter {
    typealias Request = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest
    typealias Response = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse
    let exporter: OTLPHTTPExporter<Request, Response>
    private let logger: Logger

    package init(configuration: OTel.Configuration.OTLPExporterConfiguration, logger: Logger) throws {
        self.logger = logger
        var configuration = configuration
        configuration.endpoint = configuration.logsHTTPEndpoint
        exporter = try OTLPHTTPExporter(configuration: configuration)
    }

    package func run() async throws {}

    package func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws {
        guard !batch.isEmpty else { return }
        let proto = Request.with { request in
            request.resourceLogs = [Opentelemetry_Proto_Logs_V1_ResourceLogs(batch)]
        }
        let response = try await exporter.send(proto)
        if response.hasPartialSuccess {
            // https://opentelemetry.io/docs/specs/otlp/#partial-success-1
            logger.warning("Partial success", metadata: [
                "message": "\(response.partialSuccess.errorMessage)",
                "rejected_log_records": "\(response.partialSuccess.rejectedLogRecords)",
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

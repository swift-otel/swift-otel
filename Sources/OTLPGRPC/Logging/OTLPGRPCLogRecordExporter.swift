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

import GRPCNIOTransportHTTP2
package import OTelCore
import OTLPCore
package import Logging

@available(gRPCSwift, *)
package final class OTLPGRPCLogRecordExporter: OTelLogRecordExporter {
    typealias Client = Opentelemetry_Proto_Collector_Logs_V1_LogsService.Client<HTTP2ClientTransport.Posix>
    private let client: OTLPGRPCExporter<Client>

    package init(configuration: OTel.Configuration.OTLPExporterConfiguration, logger: Logger) throws {
        client = try OTLPGRPCExporter(configuration: configuration, logger: logger)
    }

    package func run() async throws {
        try await client.run()
    }

    package func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws {
        let request = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
            request.resourceLogs = [Opentelemetry_Proto_Logs_V1_ResourceLogs(batch)]
        }

        _ = try await client.export(request)
    }

    package func forceFlush() async throws {
        try await client.forceFlush()
    }

    package func shutdown() async {
        await client.shutdown()
    }
}

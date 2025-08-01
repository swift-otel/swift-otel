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

import GRPCNIOTransportHTTP2
import Logging
import OTLPCore
import OTLPGRPC

/// A span exporter emitting span batches to an OTel collector via gRPC.
@available(gRPCSwift, *)
final class OTLPGRPCSpanExporter: OTelSpanExporter {
    typealias Client = Opentelemetry_Proto_Collector_Trace_V1_TraceService.Client<HTTP2ClientTransport.Posix>
    private let client: OTLPGRPCExporter<Client>

    init(configuration: OTel.Configuration.OTLPExporterConfiguration, logger: Logger) throws {
        client = try OTLPGRPCExporter(configuration: configuration, logger: logger)
    }

    func run() async throws {
        try await client.run()
    }

    func export(_ batch: some Collection<OTelFinishedSpan>) async throws {
        let request = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with { request in
            request.resourceSpans = [Opentelemetry_Proto_Trace_V1_ResourceSpans(batch)]
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

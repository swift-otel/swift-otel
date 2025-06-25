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

import Logging
import NIO
import NIOSSL
import OTelCore
import OTLPCore

/// A span exporter emitting span batches to an OTel collector via gRPC.
package final class OTLPGRPCSpanExporter: OTelSpanExporter {
    typealias Client = Opentelemetry_Proto_Collector_Trace_V1_TraceServiceAsyncClient
    private let client: OTLPGRPCExporter<Client>

    package init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        client = try OTLPGRPCExporter(configuration: configuration)
    }

    package func export(_ batch: some Collection<OTelFinishedSpan>) async throws {
        let request = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with { request in
            request.resourceSpans = [Opentelemetry_Proto_Trace_V1_ResourceSpans(batch)]
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

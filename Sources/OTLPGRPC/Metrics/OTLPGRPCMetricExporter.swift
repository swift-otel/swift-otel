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
package final class OTLPGRPCMetricExporter: OTelMetricExporter {
    typealias Client = Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceAsyncClient
    typealias Configuration = OTLPGRPCMetricExporterConfiguration
    private let client: OTLPGRPCExporter<Client, Configuration>

    init(
        configuration: Configuration,
        group: any EventLoopGroup = MultiThreadedEventLoopGroup.singleton,
        requestLogger: Logger = ._otelDisabled,
        backgroundActivityLogger: Logger = ._otelDisabled,
        trustRoots: NIOSSLTrustRoots = .default
    ) {
        client = OTLPGRPCExporter(
            configuration: configuration,
            group: group,
            requestLogger: requestLogger,
            backgroundActivityLogger: backgroundActivityLogger,
            trustRoots: trustRoots
        )
    }

    package func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws {
        let request = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with { request in
            request.resourceMetrics = batch.map(Opentelemetry_Proto_Metrics_V1_ResourceMetrics.init)
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

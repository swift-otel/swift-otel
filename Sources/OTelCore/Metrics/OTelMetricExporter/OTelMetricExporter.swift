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

/// Exports a batch of metrics.
///
/// - Seealso: [OTel Specification for Metric Exporter](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/metrics/sdk.md#metricexporter)
public protocol OTelMetricExporter: Sendable {
    /// Export the given batch of metrics.
    ///
    /// - Parameter batch: A batch of metrics to export.
    func export(_ batch: some Collection<OTelResourceMetrics> & Sendable) async throws

    /// Force the exporter to export any previously received metrics as soon as possible.
    func forceFlush() async throws

    /// Shut down the exporter.
    ///
    /// This method gives exporters a chance to wrap up existing work such as finishing in-flight exports while not allowing new ones anymore.
    /// Once this method returns, the exporter is to be considered shut down and further invocations of ``export(_:)``
    /// are expected to fail.
    func shutdown() async
}

/// An error indicating that an exporter has already been shut down but has been asked to export a batch of metrics.
public struct OTelMetricExporterAlreadyShutDownError: Error {
    package init() {}
}

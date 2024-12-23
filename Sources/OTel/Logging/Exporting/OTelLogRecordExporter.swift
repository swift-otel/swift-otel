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

/// A span exporter receives batches of processed logs to export them, e.g. by sending them over the network.
///
/// [OpenTelemetry specification: Log exporter](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/logs/sdk.md#logrecordexporter)
@_spi(Logging)
public protocol OTelLogRecordExporter: Sendable {
    /// Export the given batch of logs.
    ///
    /// - Parameter batch: A batch of logs to export.
    func export(_ batch: some Collection<OTelLogRecord> & Sendable) async throws

    /// Force the log exporter to export any previously received logs as soon as possible.
    func forceFlush() async throws

    /// Shut down the log exporter.
    ///
    /// This method gives exporters a chance to wrap up existing work such as finishing in-flight exports while not allowing new ones anymore.
    /// Once this method returns, the exporter is to be considered shut down and further invocations of ``export(_:)``
    /// are expected to fail.
    func shutdown() async
}

/// An error indicating that a given exporter has already been shut down while receiving an additional batch of logs to export.
@_spi(Logging)
public struct OTelLogRecordExporterAlreadyShutDownError: Error {
    /// Initialize the error.
    public init() {}
}

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

package import ServiceLifecycle

/// A span exporter receives batches of processed spans to export them, e.g. by sending them over the network.
///
/// [OpenTelemetry specification: Span exporter](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/trace/sdk.md#span-exporter)
package protocol OTelSpanExporter: Service, Sendable {
    /// Export the given batch of spans.
    ///
    /// - Parameter batch: A batch of spans to export.
    func export(_ batch: some Collection<OTelFinishedSpan> & Sendable) async throws

    /// Force the span exporter to export any previously received spans as soon as possible.
    func forceFlush() async throws

    /// Shut down the span exporter.
    ///
    /// This method gives exporters a chance to wrap up existing work such as finishing in-flight exports while not allowing new ones anymore.
    /// Once this method returns, the exporter is to be considered shut down and further invocations of ``export(_:)``
    /// are expected to fail.
    func shutdown() async
}

/// An error indicating that a given exporter has already been shut down while receiving an additional batch of spans to export.
package struct OTelSpanExporterAlreadyShutDownError: Error {
    /// Initialize the error.
    package init() {}
}

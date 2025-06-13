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

import ServiceContextModule
import ServiceLifecycle

/// Span processor allow for processing spans throught their lifetime via ``onStart(_:parentContext:)`` and ``onEnd(_:)`` calls.
/// Usually, span processors will forward ended spans to a configurable ``OTelSpanExporter``.
///
/// [OpenTelemetry specification: Span processor](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/trace/sdk.md#span-processor)
///
/// ### Implementation Notes
///
/// On shutdown, processors forwarding spans to an ``OTelSpanExporter`` MUST shutdown that exporter.
public protocol OTelSpanProcessor: Service & Sendable {
    /// Called whenever a new recording span was started.
    ///
    /// - Parameters:
    ///   - span: The mutable span that was started.
    ///   - parentContext: The span's parent service context.
    func onStart(_ span: OTelSpan, parentContext: ServiceContext) async

    /// Called whenever a recording span was ended.
    ///
    /// - Parameter span: The read-only finished span.
    func onEnd(_ span: OTelFinishedSpan) async

    /// Force span processors that batch spans to flush immediately.
    func forceFlush() async throws
}

extension OTelSpanProcessor {
    public func onStart(_ span: OTelSpan, parentContext: ServiceContext) async {}
}

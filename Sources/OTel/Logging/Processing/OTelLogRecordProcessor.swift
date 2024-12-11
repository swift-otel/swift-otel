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

/// Log processors allow for processing logs throughout their lifetime via ``onStart(_:parentContext:)`` and ``onEnd(_:)`` calls.
/// Usually, log processors will forward logs to a configurable ``OTelLogRecordExporter``.
///
/// [OpenTelemetry specification: LogRecord processor](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/logs/sdk.md#logrecordprocessor)
///
/// ### Implementation Notes
///
/// On shutdown, processors forwarding logs to an ``OTelLogRecordExporter`` MUST shutdown that exporter.
@_spi(Logging)
public protocol OTelLogRecordProcessor: Service & Sendable {
    func onEmit(_ record: inout OTelLogRecord)

    /// Force log processors that batch logs to flush immediately.
    func forceFlush() async throws
}

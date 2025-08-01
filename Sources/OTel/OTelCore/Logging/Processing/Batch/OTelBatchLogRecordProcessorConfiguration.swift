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

/// The configuration options for an ``OTelBatchLogRecordProcessor``.
struct OTelBatchLogRecordProcessorConfiguration: Sendable {
    /// The maximum queue size.
    ///
    /// - Warning: After this size is reached log will be dropped.
    var maximumQueueSize: UInt

    /// The maximum delay between two consecutive log exports.
    var scheduleDelay: Duration

    /// The maximum batch size of each export.
    ///
    /// - Note: If the queue reaches this size, a batch will be exported even if ``scheduleDelay`` has not elapsed.
    var maximumExportBatchSize: UInt

    /// The duration a single export can run until it is cancelled.
    var exportTimeout: Duration

    /// Create a batch log processor configuration.
    ///
    /// - Parameters:
    ///   - environment: The environment variables.
    ///   - maximumQueueSize: A maximum queue size used even if `OTEL_BLRP_MAX_QUEUE_SIZE` is set. Defaults to `2048` if both are `nil`.
    ///   - scheduleDelay: A schedule delay used even if `OTEL_BLRP_SCHEDULE_DELAY` is set. Defaults to `1` second if both are `nil`.
    ///   - maximumExportBatchSize: A maximum export batch size used even if `OTEL_BLRP_MAX_EXPORT_BATCH_SIZE` is set. Defaults to `512` if both are `nil`.
    ///   - exportTimeout: An export timeout used even if `OTEL_BLRP_EXPORT_TIMEOUT` is set. Defaults to `30` seconds if both are `nil`.
    init(
        environment: OTelEnvironment,
        maximumQueueSize: UInt? = nil,
        scheduleDelay: Duration? = nil,
        maximumExportBatchSize: UInt? = nil,
        exportTimeout: Duration? = nil
    ) {
        self.maximumQueueSize = environment.requiredValue(
            programmaticOverride: maximumQueueSize,
            key: "OTEL_BLRP_MAX_QUEUE_SIZE",
            defaultValue: 2048,
            transformValue: UInt.init
        )

        self.scheduleDelay = environment.requiredValue(
            programmaticOverride: scheduleDelay,
            key: "OTEL_BLRP_SCHEDULE_DELAY",
            defaultValue: .seconds(1),
            transformValue: {
                guard let milliseconds = UInt($0) else { return nil }
                return Duration.milliseconds(milliseconds)
            }
        )

        self.maximumExportBatchSize = environment.requiredValue(
            programmaticOverride: maximumExportBatchSize,
            key: "OTEL_BLRP_MAX_EXPORT_BATCH_SIZE",
            defaultValue: 512,
            transformValue: UInt.init
        )

        self.exportTimeout = environment.requiredValue(
            programmaticOverride: exportTimeout,
            key: "OTEL_BLRP_EXPORT_TIMEOUT",
            defaultValue: .seconds(30),
            transformValue: {
                guard let milliseconds = UInt($0) else { return nil }
                return Duration.milliseconds(milliseconds)
            }
        )
    }
}

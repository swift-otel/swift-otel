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

/// The configuration options for an ``OTelPeriodicExportingMetricsReader``.
public struct OTelPeriodicExportingMetricsReaderConfiguration: Sendable {
    /// The time interval between the start of two export attempts.
    public var exportInterval: Duration

    /// The maximum allowed time to export data.
    public var exportTimeout: Duration

    /// Create a configuration for a periodic metrics reader.
    ///
    /// - Parameters:
    ///   - environment: The environment variables.
    ///   - exportInterval: The time interval between the start of two export attempts.
    ///     Defaults to the value of `OTEL_METRIC_EXPORT_INTERVAL`, or 60 seconds, if the environment variable is unset.
    ///   - exportTimeout: The maximum allowed time to export data.
    ///     Defaults to the value of `OTEL_METRIC_EXPORT_TIMEOUT`, or 30 seconds, if the environment variable is unset.
    public init(
        environment: OTelEnvironment,
        exportInterval: Duration? = nil,
        exportTimeout: Duration? = nil
    ) {
        self.exportInterval = environment.requiredValue(
            programmaticOverride: exportInterval,
            key: "OTEL_METRIC_EXPORT_INTERVAL",
            defaultValue: .seconds(60),
            transformValue: {
                guard let milliseconds = UInt($0) else { return nil }
                return Duration.milliseconds(milliseconds)
            }
        )
        self.exportTimeout = environment.requiredValue(
            programmaticOverride: exportTimeout,
            key: "OTEL_METRIC_EXPORT_TIMEOUT",
            defaultValue: .seconds(30),
            transformValue: {
                guard let milliseconds = UInt($0) else { return nil }
                return Duration.milliseconds(milliseconds)
            }
        )
    }
}

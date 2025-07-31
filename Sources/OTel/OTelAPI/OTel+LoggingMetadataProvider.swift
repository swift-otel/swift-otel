//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2025 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public import Logging

extension OTel {
    /// Create a logging metadata provider, which includes metadata about the current span.
    ///
    /// - Parameter configuration: Configuration for the logging metadata provider.
    ///
    /// - Returns: A metadata provider ready to use with Logging.
    ///
    /// This API is for users who wish to bootstrap the logging system with a backend that is not provided by this
    /// package, but wish to correlate their logging events with the current instrumentation trace, if it exists.
    ///
    /// - Note: When using the OTLP logging backend, this metadata is already included in the log record.
    public static func makeLoggingMetadataProvider(
        configuration: OTel.Configuration.LoggingMetadataProviderConfiguration = .default
    ) -> Logger.MetadataProvider {
        .otel(
            traceIDKey: configuration.traceIDKey,
            spanIDKey: configuration.spanIDKey,
            traceFlagsKey: configuration.traceFlagsKey
        )
    }
}

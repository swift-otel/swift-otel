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

import AsyncAlgorithms
import Logging
import NIOConcurrencyHelpers
import ServiceLifecycle
import Tracing

@_spi(Logging)
public struct OTelLogHandler: Sendable, LogHandler {
    public var metadata: Logger.Metadata
    public var logLevel: Logger.Level
    private let processor: any OTelLogRecordProcessor
    private let resource: OTelResource
    private let nanosecondsSinceEpoch: @Sendable () -> UInt64

    public init(
        processor: any OTelLogRecordProcessor,
        logLevel: Logger.Level,
        resource: OTelResource,
        metadata: Logger.Metadata = [:]
    ) {
        self.init(
            processor: processor,
            logLevel: logLevel,
            resource: resource,
            metadata: metadata,
            nanosecondsSinceEpoch: { DefaultTracerClock.now.nanosecondsSinceEpoch }
        )
    }

    package init(
        processor: any OTelLogRecordProcessor,
        logLevel: Logger.Level,
        resource: OTelResource,
        metadata: Logger.Metadata,
        nanosecondsSinceEpoch: @escaping @Sendable () -> UInt64
    ) {
        self.processor = processor
        self.logLevel = logLevel
        self.resource = resource
        self.metadata = metadata
        self.nanosecondsSinceEpoch = nanosecondsSinceEpoch
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let codeMetadata: Logger.Metadata = [
            "code.filepath": "\(file)",
            "code.function": "\(function)",
            "code.lineno": "\(line)",
        ]

        let effectiveMetadata: Logger.Metadata
        if let metadata {
            effectiveMetadata = codeMetadata
                .merging(self.metadata, uniquingKeysWith: { $1 })
                .merging(metadata, uniquingKeysWith: { $1 })
        } else if !self.metadata.isEmpty {
            effectiveMetadata = codeMetadata.merging(self.metadata, uniquingKeysWith: { $1 })
        } else {
            effectiveMetadata = codeMetadata
        }

        var record = OTelLogRecord(
            body: message,
            level: level,
            metadata: effectiveMetadata,
            timeNanosecondsSinceEpoch: nanosecondsSinceEpoch(),
            resource: resource,
            spanContext: ServiceContext.current?.spanContext
        )

        processor.onEmit(&record)
    }
}

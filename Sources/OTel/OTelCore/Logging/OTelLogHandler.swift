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

struct OTelLogHandler: Sendable, LogHandler {
    var metadata: Logger.Metadata
    var logLevel: Logger.Level
    private let processor: any OTelLogRecordProcessor
    private let resource: OTelResource
    private let nanosecondsSinceEpoch: @Sendable () -> UInt64

    init(
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

    init(
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

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        let codeMetadata: Logger.Metadata = [
            "code.file.path": "\(event.file)",
            "code.function.name": "\(event.function)",
            "code.line.number": "\(event.line)",
        ]

        let effectiveMetadata: Logger.Metadata
        if let eventMetadata = event.metadata {
            effectiveMetadata = codeMetadata
                .merging(self.metadata, uniquingKeysWith: { $1 })
                .merging(eventMetadata, uniquingKeysWith: { $1 })
        } else if !self.metadata.isEmpty {
            effectiveMetadata = codeMetadata.merging(self.metadata, uniquingKeysWith: { $1 })
        } else {
            effectiveMetadata = codeMetadata
        }

        var record = OTelLogRecord(
            body: event.message,
            level: event.level,
            metadata: effectiveMetadata,
            timeNanosecondsSinceEpoch: nanosecondsSinceEpoch(),
            resource: resource,
            spanContext: ServiceContext.current?.spanContext
        )

        processor.onEmit(&record)
    }
}

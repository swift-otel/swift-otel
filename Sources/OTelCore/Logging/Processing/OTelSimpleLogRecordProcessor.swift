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

package import Logging

package struct OTelSimpleLogRecordProcessor<Exporter: OTelLogRecordExporter>: OTelLogRecordProcessor {
    private let logger: Logger
    private let exporter: Exporter
    private let stream: AsyncStream<OTelLogRecord>
    private let continuation: AsyncStream<OTelLogRecord>.Continuation

    package init(exporter: Exporter, logger: Logger) {
        self.logger = logger.withMetadata(component: "OTelSimpleLogRecordProcessor")
        self.exporter = exporter
        (stream, continuation) = AsyncStream.makeStream()
    }

    package func run() async throws {
        logger.info("Starting.")
        try await withThrowingTaskGroup { group in
            group.addTask { try await exporter.run() }
            for try await record in stream.cancelOnGracefulShutdown() {
                do {
                    logger.debug("Exporting log record.")
                    try await exporter.export([record])
                } catch {
                    // simple log processor does not attempt retries
                }
            }
            logger.info("Log stream ended, shutting down.")
            await exporter.shutdown()
            try await group.waitForAll()
        }
        logger.info("Shut down.")
    }

    package func onEmit(_ record: inout OTelLogRecord) {
        logger.trace("Received log record.")
        continuation.yield(record)
    }

    package func forceFlush() async throws {
        logger.info("Force flushing exporter.")
        try await exporter.forceFlush()
    }

    package func shutdown() async throws {
        logger.info("Received shutdown request.")
        await exporter.shutdown()
    }
}

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

import Logging
import ServiceLifecycle

struct OTelSimpleLogRecordProcessor<Exporter: OTelLogRecordExporter>: OTelLogRecordProcessor {
    private let logger: Logger
    private let exporter: Exporter
    private let stream: AsyncStream<OTelLogRecord>
    private let continuation: AsyncStream<OTelLogRecord>.Continuation

    init(exporter: Exporter, logger: Logger) {
        self.logger = logger.withMetadata(component: "OTelSimpleLogRecordProcessor")
        self.exporter = exporter
        (stream, continuation) = AsyncStream.makeStream()
    }

    func run() async throws {
        logger.info("Starting.")
        await withGracefulShutdownHandler {
            for await record in stream {
                do {
                    logger.trace("Exporting log record.")
                    try await exporter.export([record])
                } catch {
                    // simple log processor does not attempt retries
                }
            }
        } onGracefulShutdown: {
            logger.info("Shutting down.")
            continuation.finish()
        }
        await exporter.shutdown()
        logger.info("Shut down.")
    }

    func onEmit(_ record: inout OTelLogRecord) {
        logger.trace("Received log record.")
        continuation.yield(record)
    }

    func forceFlush() async throws {
        logger.info("Force flushing exporter.")
        try await exporter.forceFlush()
    }
}

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

package import OTelCore

package struct OTelSimpleLogRecordProcessor<Exporter: OTelLogRecordExporter>: OTelLogRecordProcessor {
    private let exporter: Exporter
    private let stream: AsyncStream<OTelLogRecord>
    private let continuation: AsyncStream<OTelLogRecord>.Continuation

    package init(exporter: Exporter) {
        self.exporter = exporter
        (stream, continuation) = AsyncStream.makeStream()
    }

    package func run() async throws {
        for try await record in stream.cancelOnGracefulShutdown() {
            do {
                try await exporter.export([record])
            } catch {
                // simple log processor does not attempt retries
            }
        }
    }

    package func onEmit(_ record: inout OTelLogRecord) {
        continuation.yield(record)
    }

    package func forceFlush() async throws {
        try await exporter.forceFlush()
    }

    package func shutdown() async throws {
        await exporter.shutdown()
    }
}

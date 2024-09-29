//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2023 Moritz Lang and the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_spi(Logging)
public struct OTelSimpleLogRecordProcessor<Exporter: OTelLogRecordExporter>: OTelLogRecordProcessor {
    private let exporter: Exporter
    private let stream: AsyncStream<OTelLogRecord>
    private let continuation: AsyncStream<OTelLogRecord>.Continuation

    public init(exporter: Exporter) {
        self.exporter = exporter
        (stream, continuation) = AsyncStream.makeStream()
    }

    public func run() async throws {
        for try await record in stream.cancelOnGracefulShutdown() {
            do {
                try await exporter.export([record])
            } catch {
                // simple log processor does not attempt retries
            }
        }
    }

    public func onEmit(_ record: inout OTelLogRecord) {
        continuation.yield(record)
    }

    public func forceFlush() async throws {
        try await exporter.forceFlush()
    }

    public func shutdown() async throws {
        await exporter.shutdown()
    }
}

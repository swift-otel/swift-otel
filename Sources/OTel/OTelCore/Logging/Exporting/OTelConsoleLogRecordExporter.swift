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

#if canImport(FoundationEssentials)
import struct FoundationEssentials.Date
#else
import struct Foundation.Date
#endif
import ServiceLifecycle

struct OTelConsoleLogRecordExporter: OTelLogRecordExporter {
    func run() async throws {
        /// > The exporter’s output format is unspecified and can vary between implementations. Documentation SHOULD
        /// > warn users about this. The following wording is recommended (modify as needed):
        /// > >
        /// > > This exporter is intended for debugging and learning purposes. It is not recommended for production use.
        /// > > The output format is not standardized and can change at any time.
        /// > >
        /// > > If a standardized format for exporting logs to stdout is desired, consider using the File Exporter, if
        /// > > available. However, please review the status of the File Exporter and verify if it is stable and
        /// > > production-ready.
        /// — source: https://opentelemetry.io/docs/specs/otel/logs/sdk_exporters/stdout/
        print(
            """
            ---
            WARNING: Using the console log exporter.
            This exporter is intended for debugging and learning purposes. It is not recommended for production use.
            The output format is not standardized and can change at any time.
            ---
            """
        )
        // No background work needed, but we'll keep the run method running until its cancelled.
        try await gracefulShutdown()
    }

    func export(_ batch: some Collection<OTelLogRecord> & Sendable) {
        for logRecord in batch {
            print(logRecord.consoleFormatted)
        }
    }

    func forceFlush() {}

    func shutdown() {}
}

extension OTelLogRecord {
    var consoleFormatted: String {
        // 2024-01-15 14:30:45.123 [INFO] user-api [req-456] User login successful user_id=abc123 duration_ms=245
        let date = Date(timeIntervalSince1970: Double(self.timeNanosecondsSinceEpoch) / 1_000_000_000)
        var fields: [String] = []
        fields.append(date.formatted(.iso8601))
        fields.append("[\(self.level)]")
        switch self.resource.attributes["service.name"]?.toSpanAttribute() {
        case .string(let serviceName): fields.append(serviceName)
        default: fields.append("unknown")
        }
        if let spanContext = self.spanContext {
            fields.append("[\(spanContext.spanID)]")
        } else {
            fields.append("[unknown]")
        }
        fields.append("\(self.body)")
        for (key, value) in self.metadata.filter({ $0.key != "code.function" }) {
            fields.append("\(key)=\(value)")
        }
        return fields.joined(separator: " ")
    }
}

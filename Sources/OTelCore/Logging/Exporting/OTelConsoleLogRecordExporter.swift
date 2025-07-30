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

package struct OTelConsoleLogRecordExporter: OTelLogRecordExporter {
    package init() {}

    package func run() {
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
    }

    package func export(_ batch: some Collection<OTelLogRecord> & Sendable) {
        for logRecord in batch {
            print(logRecord)
        }
    }

    package func forceFlush() {}

    package func shutdown() {}
}

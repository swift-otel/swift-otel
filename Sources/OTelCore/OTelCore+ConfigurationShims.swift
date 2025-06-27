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

import Tracing

extension OTelResource {
    package init(configuration: OTel.Configuration) {
        let attributes = configuration.resourceAttributes.mapValues { $0.toSpanAttribute() }
        self.init(attributes: SpanAttributes(attributes))
    }
}

extension OTelBatchLogRecordProcessorConfiguration {
    package init(configuration: OTel.Configuration.LogsConfiguration.BatchLogRecordProcessorConfiguration) {
        self.init(
            environment: [:],
            maximumQueueSize: UInt(configuration.maxQueueSize),
            scheduleDelay: configuration.scheduleDelay,
            maximumExportBatchSize: UInt(configuration.maxExportBatchSize),
            exportTimeout: configuration.exportTimeout
        )
    }
}

extension OTelPeriodicExportingMetricsReaderConfiguration {
    package init(configuration: OTel.Configuration.MetricsConfiguration) {
        self.init(
            environment: [:],
            exportInterval: configuration.exportInterval,
            exportTimeout: configuration.exportTimeout
        )
    }
}

extension OTelBatchSpanProcessorConfiguration {
    package init(configuration: OTel.Configuration.TracesConfiguration.BatchSpanProcessorConfiguration) {
        self.init(
            environment: [:],
            maximumQueueSize: UInt(configuration.maxQueueSize),
            scheduleDelay: configuration.scheduleDelay,
            maximumExportBatchSize: UInt(configuration.maxExportBatchSize),
            exportTimeout: configuration.exportTimeout
        )
    }
}

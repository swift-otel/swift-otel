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
import OTLPCore

extension Opentelemetry_Proto_Logs_V1_LogRecord {
    package init(_ logRecord: OTelLogRecord) {
        self.init()
        timeUnixNano = logRecord.timeNanosecondsSinceEpoch
        observedTimeUnixNano = logRecord.timeNanosecondsSinceEpoch

        severityNumber = .init(logRecord.level)
        severityText = String(describing: logRecord.level)

        body = .init(logRecord.body.description)

        attributes = .init(logRecord.metadata)
        droppedAttributesCount = 0 // TODO: do we need this?

        flags = 0 // TODO: do we need this?

        if let spanContext = logRecord.spanContext {
            traceID = spanContext.traceID.data
            spanID = spanContext.spanID.data
        }
    }
}

extension Opentelemetry_Proto_Logs_V1_SeverityNumber {
    init(_ level: Logger.Level) {
        // https://opentelemetry.io/docs/specs/otel/logs/data-model/#field-severitynumber
        switch level {
        case .trace: self = .trace
        case .debug: self = .debug
        case .info: self = .info
        case .notice: self = .info2
        case .warning: self = .warn
        case .error: self = .error
        case .critical: self = .error2
        }
    }
}

extension [Opentelemetry_Proto_Common_V1_KeyValue] {
    init(_ metadata: Logger.Metadata) {
        self.init()
        reserveCapacity(metadata.count)
        for (key, value) in metadata {
            let attribute = Opentelemetry_Proto_Common_V1_KeyValue.with {
                $0.key = key
                $0.value = .init(value)
            }
            append(attribute)
        }
    }
}

extension Opentelemetry_Proto_Common_V1_KeyValueList {
    init(_ metadata: Logger.Metadata) {
        self.init()
        values = [Opentelemetry_Proto_Common_V1_KeyValue](metadata)
    }
}

extension Opentelemetry_Proto_Common_V1_AnyValue {
    init(_ metadataValue: Logger.MetadataValue) {
        self.init()
        switch metadataValue {
        case .string(let string):
            stringValue = string
        case .stringConvertible(let stringConvertible):
            stringValue = stringConvertible.description
        case .dictionary(let metadata):
            kvlistValue = Opentelemetry_Proto_Common_V1_KeyValueList(metadata)
        case .array(let array):
            arrayValue = .with {
                $0.values = array.map { metadataValue in Opentelemetry_Proto_Common_V1_AnyValue(metadataValue) }
            }
        }
    }
}

extension Opentelemetry_Proto_Logs_V1_ResourceLogs {
    package init(_ logRecords: some Collection<OTelLogRecord>) {
        self.init()
        if let resource = logRecords.first?.resource {
            self.resource = .init(resource)
        }

        scopeLogs = [Opentelemetry_Proto_Logs_V1_ScopeLogs.with {
            $0.scope = .swiftOTelScope
            $0.logRecords = logRecords.map(Opentelemetry_Proto_Logs_V1_LogRecord.init)
        }]
    }
}

extension Opentelemetry_Proto_Common_V1_InstrumentationScope {
    fileprivate static let swiftOTelScope = Opentelemetry_Proto_Common_V1_InstrumentationScope.with {
        $0.name = "swift-otel"
        $0.version = OTelLibrary.version
    }
}

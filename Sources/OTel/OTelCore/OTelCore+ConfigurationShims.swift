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

import Logging
import Tracing

extension OTelResource {
    init(configuration: OTel.Configuration) {
        var attributes = configuration.resourceAttributes.mapValues { $0.toSpanAttribute() }

        // If service.name is also provided in OTEL_RESOURCE_ATTRIBUTES, then OTEL_SERVICE_NAME takes precedence.
        // https://opentelemetry.io/docs/languages/sdk-configuration/general/#otel_service_name
        // https://opentelemetry.io/docs/languages/sdk-configuration/general/#otel_resource_attributes
        if let serviceName = attributes["service.name"], configuration.serviceName == OTel.Configuration.default.serviceName {
            attributes["service.name"] = serviceName
        } else {
            attributes["service.name"] = .string(configuration.serviceName)
        }

        self.init(attributes: SpanAttributes(attributes))
    }
}

extension Logging.Logger.Level {
    init(_ level: OTel.Configuration.LogLevel) {
        switch level.backing {
        case .error: self = .error
        case .warning: self = .warning
        case .info: self = .info
        case .debug: self = .debug
        case .trace: self = .trace
        }
    }
}

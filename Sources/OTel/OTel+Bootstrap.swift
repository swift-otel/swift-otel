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

import class Foundation.ProcessInfo
import Logging
import Metrics
import ServiceLifecycle
import Tracing

// MARK: - API

extension OTel {
    public static func bootstrap(configuration: Configuration = .default) throws -> some Service {
        try Self.bootstrap(configuration: configuration, environment: ProcessInfo.processInfo.environment)
    }
}

// MARK: - Internal

extension OTel {
    internal static func bootstrap(configuration: Configuration = .default, environment: [String: String]) throws -> some Service {
        var configuration = configuration
        configuration.applyEnvironmentOverrides(environment: environment)

        var services: [Service] = []

        if configuration.logs.enabled {
            try services.append(bootstrapLogs(configuration: configuration))
        }
        if configuration.metrics.enabled {
            try services.append(bootstrapMetrics(configuration: configuration))
        }
        if configuration.traces.enabled {
            try services.append(bootstrapTraces(configuration: configuration))
        }

        return ServiceGroup(services: services, logger: Logger(label: "OTelServiceGroup"))
    }

    internal static func bootstrapTraces(configuration: OTel.Configuration) throws -> some Service {
        let backend = try makeTracingBackend(configuration: configuration)
        InstrumentationSystem.bootstrap(backend.factory)
        return backend.service
    }

    internal static func bootstrapMetrics(configuration: OTel.Configuration) throws -> some Service {
        let backend = try makeMetricsBackend(configuration: configuration)
        MetricsSystem.bootstrap(backend.factory)
        return backend.service
    }

    internal static func bootstrapLogs(configuration: OTel.Configuration) throws -> some Service {
        let backend = try makeLoggingBackend(configuration: configuration)
        LoggingSystem.bootstrap(backend.factory)
        return backend.service
    }
}

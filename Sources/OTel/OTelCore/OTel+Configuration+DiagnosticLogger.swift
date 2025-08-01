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

extension OTel.Configuration {
    func makeDiagnosticLogger() -> Logger {
        var logger = switch self.diagnosticLogger.backing {
        case .console:
            Logger(label: "swift-otel", factory: { label in StreamLogHandler.standardError(label: label) })
        case .custom(let logger):
            // TODO: would a better configuration API accept a custom factory, which would allow per-logger labels?
            logger
        }
        // Environment variable overrides may not have been applied, so we explicitly check here.
        logger.logLevel = Self.diagnosticLogLevelEnvironmentOverride ?? Logger.Level(self.diagnosticLogLevel)
        return logger
    }

    fileprivate static let diagnosticLogLevelEnvironmentOverride: Logger.Level? = {
        switch ProcessInfo.processInfo.environment.getStringValue(.logLevel) {
        case "trace": .trace
        case "debug": .debug
        case "info": .info
        case "notice": .notice
        case "warning": .warning
        case "error": .error
        case "critical": .critical
        default: nil
        }
    }()
}

extension Logger {
    func withMetadata(component: String) -> Self {
        var result = self
        result[metadataKey: "component"] = "\(component)"
        return result
    }
}

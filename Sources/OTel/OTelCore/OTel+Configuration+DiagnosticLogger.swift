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
import class FoundationEssentials.ProcessInfo
#else
import class Foundation.ProcessInfo
#endif
import Logging

extension OTel.Configuration {
    func makeDiagnosticLogger() -> Logger {
        var logger = switch self.diagnosticLogger.backing {
        case .console:
            Logger(label: "swift-otel", factory: { label in StreamLogHandler.standardError(label: label) })
        case .custom(let logger):
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

extension Logger {
    func log(
        level: Logger.Level,
        error: some Error,
        message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.log(
            level: level,
            message(),
            metadata: (metadata() ?? [:]).merging(["error": "\(error)", "error_type": "\(type(of: error))"]) { $1 },
            file: file,
            function: function,
            line: line
        )
    }
}

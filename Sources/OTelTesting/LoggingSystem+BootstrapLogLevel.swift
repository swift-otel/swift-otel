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

@testable package import Logging

extension LoggingSystem {
    /// Bootstraps the logging system for testing with a minimum log level.
    ///
    /// - Parameter logLevel: The minimum log level.
    package static func bootstrapInternal(logLevel: Logger.Level) {
        LoggingSystem.bootstrapInternal { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = logLevel
            return handler
        }
    }
}

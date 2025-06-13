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

import Foundation
import Logging
import Tracing

/// A resource detector retrieving process-related attributes.
public struct OTelProcessResourceDetector: OTelResourceDetector, CustomStringConvertible {
    public let description = "process"

    private let processIdentifier: @Sendable () -> Int32
    private let executableName: @Sendable () -> String
    private let executablePath: @Sendable () -> String
    private let command: @Sendable () -> String?
    private let commandLine: @Sendable () -> String
    private let owner: @Sendable () -> String?

    /// Create a process resource detector.
    public init() {
        self.init(
            processIdentifier: { ProcessInfo.processInfo.processIdentifier },
            executableName: { ProcessInfo.processInfo.processName },
            executablePath: { ProcessInfo.processInfo.arguments[0] },
            command: { ProcessInfo.processInfo.arguments.count > 1 ? ProcessInfo.processInfo.arguments[1] : nil },
            commandLine: { ProcessInfo.processInfo.arguments.joined(separator: " ") },
            owner: {
                #if os(macOS) || os(Linux)
                    return ProcessInfo.processInfo.userName
                #else
                    return nil
                #endif
            }
        )
    }

    @_spi(Testing)
    public init(
        processIdentifier: @escaping @Sendable () -> Int32,
        executableName: @escaping @Sendable () -> String,
        executablePath: @escaping @Sendable () -> String,
        command: @escaping @Sendable () -> String?,
        commandLine: @escaping @Sendable () -> String,
        owner: @escaping @Sendable () -> String?
    ) {
        self.processIdentifier = processIdentifier
        self.executableName = executableName
        self.executablePath = executablePath
        self.command = command
        self.commandLine = commandLine
        self.owner = owner
    }

    public func resource(logger: Logger) -> OTelResource {
        var attributes: SpanAttributes = [:]

        attributes["process.pid"] = SpanAttribute.int32(processIdentifier())
        attributes["process.executable.name"] = "\(executableName())"
        attributes["process.executable.path"] = "\(executablePath())"
        attributes["process.command"] = command().map { "\($0)" }
        attributes["process.command_line"] = "\(commandLine())"
        attributes["process.owner"] = owner().map { "\($0)" }

        return OTelResource(attributes: attributes)
    }
}

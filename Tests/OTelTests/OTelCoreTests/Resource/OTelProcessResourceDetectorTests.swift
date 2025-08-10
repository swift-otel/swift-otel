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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Logging
@testable import OTel
import XCTest

final class OTelProcessResourceDetectorTests: XCTestCase {
    override func setUp() {
        LoggingSystem.bootstrapInternal(logLevel: .trace)
    }

    func test_resource_returnsResourceWithProcessRelatedAttributes() {
        let detector = OTelProcessResourceDetector(
            processIdentifier: { 42 },
            executableName: { "test" },
            executablePath: { "/usr/bin/swift" },
            command: { "--version" },
            commandLine: { "/usr/bin/swift --version" },
            owner: { "test" }
        )

        let resource = detector.resource(logger: Logger(label: #function))

        XCTAssertEqual(resource, OTelResource(attributes: [
            "process.pid": .int32(42),
            "process.executable.name": "test",
            "process.executable.path": "/usr/bin/swift",
            "process.command": "--version",
            "process.command_line": "/usr/bin/swift --version",
            "process.owner": "test",
        ]))
    }

    func test_resource_withDefaultValueGetters_returnsResourceWithProcessRelatedAttributes() {
        let detector = OTelProcessResourceDetector()

        let resource = detector.resource(logger: Logger(label: #function))

        XCTAssertNotNil(resource.attributes["process.pid"])
        XCTAssertNotNil(resource.attributes["process.executable.name"])
        XCTAssertNotNil(resource.attributes["process.executable.path"])
        XCTAssertNotNil(resource.attributes["process.command_line"])
    }
}

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
@testable import OTel
import ServiceLifecycle
import XCTest

final class OTelNoOpSpanProcessorTests: XCTestCase {
    func test_run_onGracefulShutdown_stopsExecuting() async {
        LoggingSystem.bootstrapInternal(logLevel: .trace)
        let processor = OTelNoOpSpanProcessor()
        let logger = Logger(label: #function)
        let serviceGroup = ServiceGroup(services: [processor], logger: logger)

        let startExpectation = expectation(description: "Expected task to start executing.")
        let shutDownExpectation = expectation(description: "Expected service group to shut down.")
        Task {
            startExpectation.fulfill()
            try await serviceGroup.run()
            shutDownExpectation.fulfill()
        }

        await fulfillment(of: [startExpectation], timeout: 0.1)
        await serviceGroup.triggerGracefulShutdown()
        await fulfillment(of: [shutDownExpectation], timeout: 0.1)
    }
}

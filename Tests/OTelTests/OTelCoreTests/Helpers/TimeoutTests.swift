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

@testable import OTel
import XCTest

final class TimeoutTests: XCTestCase {
    func test_withTimeout_operationCompletesWithinTime_returnsResult() async throws {
        let expectation = expectation(description: "cancellation handler not called")
        expectation.isInverted = true
        let result = try? await withTimeout(.milliseconds(1)) {
            try await withTaskCancellationHandler {
                try await Task.sleep(for: .nanoseconds(1))
                return 42
            } onCancel: {
                expectation.fulfill()
            }
        }
        XCTAssertEqual(result, 42)
        await fulfillment(of: [expectation], timeout: 0)
    }

    func test_withTimeout_operationDoesNotCompletesWithinTime_throwsCancellationError() async throws {
        let expectation = expectation(description: "cancellation handler called")
        let result = try? await withTimeout(.nanoseconds(1)) {
            try await withTaskCancellationHandler {
                try await Task.sleep(for: .milliseconds(1))
                return 42
            } onCancel: {
                expectation.fulfill()
            }
        }
        XCTAssertEqual(result, nil)
        await fulfillment(of: [expectation], timeout: 0)
    }

    func test_withTimeout_operationThrowsError_throwsError() async throws {
        let expectation = expectation(description: "cancellation handler not called")
        expectation.isInverted = true
        @Sendable func alwaysThrows() throws -> Int {
            struct SomeError: Error {}
            throw SomeError()
        }
        let result = try? await withTimeout(.milliseconds(1)) {
            try await withTaskCancellationHandler {
                try await Task.sleep(for: .nanoseconds(1))
                return try alwaysThrows()
            } onCancel: {
                expectation.fulfill()
            }
        }
        XCTAssertEqual(result, nil)
        await fulfillment(of: [expectation], timeout: 0)
    }
}

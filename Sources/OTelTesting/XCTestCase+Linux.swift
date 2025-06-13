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

// Adds the fulfillment(of:) XCTest method on Linux
// https://github.com/apple/swift-corelibs-xctest/issues/436#issuecomment-1703589930

#if os(Linux) && swift(<5.10)
    import XCTest

    extension XCTestCase {
        /// Waits on a group of expectations for up to the specified timeout,
        /// optionally enforcing their order of fulfillment.
        ///
        /// - Parameters:
        ///     - expectations: An array of expectations that must be fulfilled.
        ///     - seconds: The number of seconds within which all expectations must
        ///         be fulfilled. The default timeout allows the test to run until
        ///         it reaches its execution time allowance.
        ///     - enforceOrderOfFulfillment: If `true`, the expectations specified
        ///         by the `expectations` parameter must be satisfied in the order
        ///         they appear in the array.
        ///
        /// Expectations can only appear in the list once. This function may return
        /// early based on fulfillment of the provided expectations.
        ///
        /// - Note: If you do not specify a timeout when calling this function, it
        ///     is recommended that you enable test timeouts to prevent a runaway
        ///     expectation from hanging the test.
        package func fulfillment(
            of expectations: [XCTestExpectation],
            timeout: TimeInterval,
            enforceOrder: Bool = false
        ) async {
            await withCheckedContinuation { continuation in
                // This function operates by blocking a background thread instead of one owned by libdispatch or by the
                // Swift runtime (as used by Swift concurrency.) To ensure we use a thread owned by neither subsystem,
                // use Foundation's Thread.detachNewThread(_:).
                Thread.detachNewThread { [self] in
                    wait(for: expectations, timeout: timeout, enforceOrder: enforceOrder)
                    continuation.resume()
                }
            }
        }
    }
#endif

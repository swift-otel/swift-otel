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

@testable import OTelCore
import OTelTesting
import XCTest

final class FloatingPointCounterTests: XCTestCase {
    func test_increment() {
        let counter = FloatingPointCounter(name: "my_floating_point_counter", attributes: [])
        XCTAssertEqual(counter.atomicValue, 0)

        counter.increment(by: 0)
        XCTAssertEqual(counter.atomicValue, 0)

        counter.increment()
        XCTAssertEqual(counter.atomicValue, 1)

        counter.increment(by: 0.1)
        XCTAssertEqual(counter.atomicValue, 1.1)

        counter.reset()
        XCTAssertEqual(counter.atomicValue, 0)
    }

    func test_increment_concurrent() async {
        let counter = FloatingPointCounter(name: "my_floating_point_counter", attributes: [])
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 100_000 {
                group.addTask {
                    counter.increment(by: 0.5)
                }
            }
        }
        XCTAssertEqual(counter.atomicValue, 50000)
    }
}

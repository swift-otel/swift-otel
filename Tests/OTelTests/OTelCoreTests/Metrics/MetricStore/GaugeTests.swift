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

final class GaugeTests: XCTestCase {
    func test_incrementDecrement() {
        let gauge = Gauge(name: "my_gauge", attributes: [])
        XCTAssertEqual(gauge.doubleAtomicValue, 0.0)

        gauge.decrement(by: 0)
        XCTAssertEqual(gauge.doubleAtomicValue, 0.0)

        gauge.increment(by: 0)
        XCTAssertEqual(gauge.doubleAtomicValue, 0.0)

        gauge.decrement()
        XCTAssertEqual(gauge.doubleAtomicValue, -1.0)

        gauge.decrement(by: 2)
        XCTAssertEqual(gauge.doubleAtomicValue, -3.0)

        gauge.increment()
        XCTAssertEqual(gauge.doubleAtomicValue, -2.0)

        gauge.increment(by: 2.5)
        XCTAssertEqual(gauge.doubleAtomicValue, 0.5)

        gauge.set(to: 42)
        XCTAssertEqual(gauge.doubleAtomicValue, 42.0)

        gauge.set(to: 42.99)
        XCTAssertEqual(gauge.doubleAtomicValue, 42.99)
    }

    func test_incrementDecrement_concurrent() async {
        let gauge = Gauge(name: "my_gauge", attributes: [])
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 100_000 {
                group.addTask {
                    gauge.increment(by: 3.5)
                }
            }
            for _ in 0 ..< 100_000 {
                group.addTask {
                    gauge.decrement(by: 2.5)
                }
            }
        }
        XCTAssertEqual(gauge.doubleAtomicValue, 100_000.0)
    }
}

extension Gauge {
    fileprivate var doubleAtomicValue: Double { Double(bitPattern: atomic.load(ordering: .relaxed)) }
}

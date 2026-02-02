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

import XCTest

@testable import OTel

final class GaugeMeasurementTests: XCTestCase {
    func test_measure_returnsGauge() {
        let gauge = Gauge(name: "my_gauge", attributes: [])
        gauge.measure().data.assertIsGaugeWithOneValue(.double(0))

        gauge.decrement(by: 0)
        gauge.measure().data.assertIsGaugeWithOneValue(.double(0))

        gauge.increment(by: 0)
        gauge.measure().data.assertIsGaugeWithOneValue(.double(0))

        gauge.decrement()
        gauge.measure().data.assertIsGaugeWithOneValue(.double(-1))

        gauge.decrement(by: 2)
        gauge.measure().data.assertIsGaugeWithOneValue(.double(-3))

        gauge.increment()
        gauge.measure().data.assertIsGaugeWithOneValue(.double(-2))

        gauge.increment(by: 2)
        gauge.measure().data.assertIsGaugeWithOneValue(.double(0))

        gauge.set(to: 42)
        gauge.measure().data.assertIsGaugeWithOneValue(.double(42))
    }

    func test_measure_followingConcurrentIncrementDecerement_returnsGauge() async {
        let gauge = Gauge(name: "my_gauge", attributes: [])
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100_000 {
                group.addTask {
                    gauge.increment(by: 3.5)
                }
            }
            for _ in 0..<100_000 {
                group.addTask {
                    gauge.decrement(by: 2.5)
                }
            }
        }
        gauge.measure().data.assertIsGaugeWithOneValue(.double(100_000))
    }

    func test_measure_measurementIncludesIdentifyingFields() {
        let gauge = Counter(name: "my_gauge", unit: "bytes", description: "some description", attributes: [])
        XCTAssertEqual(gauge.measure().name, "my_gauge")
        XCTAssertEqual(gauge.measure().unit, "bytes")
        XCTAssertEqual(gauge.measure().description, "some description")
    }

    func test_measure_measurementIncludesLabelsAsAttributes() throws {
        let attributes = [("A", "one"), ("B", "two")]
        let gauge = Gauge(name: "my_gauge", attributes: attributes)
        let point = try XCTUnwrap(gauge.measure().data.asGauge?.points.first)
        for (key, value) in attributes {
            XCTAssert(point.attributes.contains { $0.key == key && $0.value == value })
        }
    }

    func test_measure_measurementIncludesTimestamp() throws {
        let gauge = Gauge(name: "my_gauge", attributes: [])
        XCTAssertEqual(gauge.measure(instant: .constant(42)).data.asGauge?.points.first?.timeNanosecondsSinceEpoch, 42)
    }
}

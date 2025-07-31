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

final class FloatingPointCounterMeasurementTests: XCTestCase {
    func test_measure_returnsCumulativeSum() {
        let counter = FloatingPointCounter(name: "my_floating_point_counter", attributes: [])
        counter.measure().data.assertIsCumulativeSumWithOneValue(.double(0))

        counter.increment(by: 0)
        counter.measure().data.assertIsCumulativeSumWithOneValue(.double(0))

        counter.increment()
        counter.measure().data.assertIsCumulativeSumWithOneValue(.double(1))

        counter.increment(by: 1)
        counter.measure().data.assertIsCumulativeSumWithOneValue(.double(2))

        counter.increment(by: 2)
        counter.measure().data.assertIsCumulativeSumWithOneValue(.double(4))

        counter.increment(by: 0.5)
        counter.measure().data.assertIsCumulativeSumWithOneValue(.double(4.5))

        counter.reset()
        counter.measure().data.assertIsCumulativeSumWithOneValue(.double(0))
    }

    func test_measure_followingConcurrentIncrement_returnsCumulativeSum() async {
        let counter = FloatingPointCounter(name: "my_floating_point_counter", attributes: [])
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 100_000 {
                group.addTask {
                    counter.increment(by: 0.5)
                }
            }
        }
        counter.measure().data.assertIsCumulativeSumWithOneValue(.double(50000))
    }

    func test_measure_measurementIncludesIdentifyingFields() {
        let counter = FloatingPointCounter(name: "my_floating_point_counter", unit: "bytes", description: "some description", attributes: [])
        XCTAssertEqual(counter.measure().name, "my_floating_point_counter")
        XCTAssertEqual(counter.measure().unit, "bytes")
        XCTAssertEqual(counter.measure().description, "some description")
    }

    func test_measure_measurementIncludesLabelsAsAttributes() throws {
        let attributes = [("A", "one"), ("B", "two")]
        let counter = FloatingPointCounter(name: "my_floating_point_counter", attributes: attributes)
        let point = try XCTUnwrap(counter.measure().data.asSum?.points.first)
        for (key, value) in attributes {
            XCTAssert(point.attributes.contains { $0.key == key && $0.value == value })
        }
    }

    func test_measure_measurementIncludesTimestamp() throws {
        let counter = FloatingPointCounter(name: "my_floating_point_counter", attributes: [])
        XCTAssertEqual(counter.measure(instant: .constant(42)).data.asSum?.points.first?.timeNanosecondsSinceEpoch, 42)
    }
}

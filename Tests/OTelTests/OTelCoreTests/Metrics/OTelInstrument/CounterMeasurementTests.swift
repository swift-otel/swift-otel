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

final class CounterMeasurementTests: XCTestCase {
    func test_measure_returnsCumulativeSum() {
        let counter = Counter(name: "my_counter", attributes: [])
        counter.measure().data.assertIsCumulativeSumWithOneValue(.int64(0))

        counter.increment(by: 0)
        counter.measure().data.assertIsCumulativeSumWithOneValue(.int64(0))

        counter.increment()
        counter.measure().data.assertIsCumulativeSumWithOneValue(.int64(1))

        counter.increment(by: 1)
        counter.measure().data.assertIsCumulativeSumWithOneValue(.int64(2))

        counter.increment(by: 2)
        counter.measure().data.assertIsCumulativeSumWithOneValue(.int64(4))

        counter.reset()
        counter.measure().data.assertIsCumulativeSumWithOneValue(.int64(0))
    }

    func test_measure_followingConcurrentIncrement_returnsCumulativeSum() async {
        let counter = Counter(name: "my_counter", attributes: [])
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100_000 {
                group.addTask {
                    counter.increment(by: 2)
                }
            }
        }
        counter.measure().data.assertIsCumulativeSumWithOneValue(.int64(200_000))
    }

    func test_measure_measurementIncludesIdentifyingFields() {
        let counter = Counter(name: "my_counter", unit: "bytes", description: "some description", attributes: [])
        XCTAssertEqual(counter.measure().name, "my_counter")
        XCTAssertEqual(counter.measure().unit, "bytes")
        XCTAssertEqual(counter.measure().description, "some description")
    }

    func test_measure_measurementIncludesLabelsAsAttributes() throws {
        let attributes = [("A", "one"), ("B", "two")]
        let counter = Counter(name: "my_counter", attributes: attributes)
        let point = try XCTUnwrap(counter.measure().data.asSum?.points.first)
        for (key, value) in attributes {
            XCTAssert(point.attributes.contains { $0.key == key && $0.value == value })
        }
    }

    func test_measure_measurementIncludesTimestamp() throws {
        let counter = Counter(name: "my_counter", attributes: [])
        XCTAssertEqual(counter.measure(instant: .constant(42)).data.asSum?.points.first?.timeNanosecondsSinceEpoch, 42)
    }
}

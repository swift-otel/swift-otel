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

final class HistogramMeasurementTests: XCTestCase {
    func test_measure_returnsCumulativeHistogram() {
        let histogram = DurationHistogram(name: "my_histogram", attributes: [], buckets: [
            .milliseconds(100),
            .milliseconds(250),
            .milliseconds(500),
            .seconds(1),
        ])
        histogram.measure().data.assertIsCumulativeHistogramWith(count: 0, sum: 0.0, buckets: [
            .init(upperBound: 0.1, count: 0),
            .init(upperBound: 0.25, count: 0),
            .init(upperBound: 0.5, count: 0),
            .init(upperBound: 1.0, count: 0),
            .init(upperBound: .infinity, count: 0),
        ])

        histogram.record(.milliseconds(400))
        histogram.measure().data.assertIsCumulativeHistogramWith(count: 1, sum: 0.4, buckets: [
            .init(upperBound: 0.1, count: 0),
            .init(upperBound: 0.25, count: 0),
            .init(upperBound: 0.5, count: 1),
            .init(upperBound: 1.0, count: 0),
            .init(upperBound: .infinity, count: 0),
        ])

        histogram.record(.milliseconds(600))
        histogram.measure().data.assertIsCumulativeHistogramWith(count: 2, sum: 1.0, buckets: [
            .init(upperBound: 0.1, count: 0),
            .init(upperBound: 0.25, count: 0),
            .init(upperBound: 0.5, count: 1),
            .init(upperBound: 1.0, count: 1),
            .init(upperBound: .infinity, count: 0),
        ])

        histogram.record(.milliseconds(1200))
        histogram.measure().data.assertIsCumulativeHistogramWith(count: 3, sum: 2.2, buckets: [
            .init(upperBound: 0.1, count: 0),
            .init(upperBound: 0.25, count: 0),
            .init(upperBound: 0.5, count: 1),
            .init(upperBound: 1.0, count: 1),
            .init(upperBound: .infinity, count: 1),
        ])

        histogram.record(.milliseconds(80))
        histogram.measure().data.assertIsCumulativeHistogramWith(count: 4, sum: 2.28, buckets: [
            .init(upperBound: 0.1, count: 1),
            .init(upperBound: 0.25, count: 0),
            .init(upperBound: 0.5, count: 1),
            .init(upperBound: 1.0, count: 1),
            .init(upperBound: .infinity, count: 1),
        ])
    }

    func test_measure_followingConcurrentRecord_returnsCumulativeHistogram() async {
        let histogram = DurationHistogram(name: "my_histogram", attributes: [], buckets: [.milliseconds(500)])
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 100_000 {
                group.addTask {
                    histogram.record(.milliseconds(400))
                }
            }
            for _ in 0 ..< 100_000 {
                group.addTask {
                    histogram.record(.milliseconds(600))
                }
            }
        }
        histogram.measure().data.assertIsCumulativeHistogramWith(count: 200_000, sum: 100_000, buckets: [
            .init(upperBound: 0.5, count: 100_000),
            .init(upperBound: .infinity, count: 100_000),
        ])
    }

    func test_measure_measurementIncludesIdentifyingFields() {
        let histogram = DurationHistogram(name: "my_histogram", unit: "bytes", description: "some description", attributes: [], buckets: [])
        XCTAssertEqual(histogram.measure().name, "my_histogram")
        XCTAssertEqual(histogram.measure().unit, "bytes")
        XCTAssertEqual(histogram.measure().description, "some description")
    }

    func test_measure_measurementIncludesLabelsAsAttributes() throws {
        let labels = [("A", "one"), ("B", "two")]
        let histogram = DurationHistogram(name: "my_histogram", attributes: labels, buckets: [])
        let attributes = try XCTUnwrap(histogram.measure().data.asHistogram?.points.first?.attributes)
        for (key, value) in labels {
            XCTAssert(attributes.contains { $0.key == key && $0.value == value })
        }
    }

    func test_measure_measurementIncludesTimestamp() throws {
        let histogram = DurationHistogram(name: "my_histogram", attributes: [], buckets: [])
        XCTAssertEqual(histogram.measure(instant: .constant(42)).data.asHistogram?.points.first?.timeNanosecondsSinceEpoch, 42)
    }
}

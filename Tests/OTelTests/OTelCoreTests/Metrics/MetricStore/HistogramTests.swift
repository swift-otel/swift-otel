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

final class HistogramTests: XCTestCase {
    func test_record() {
        let histogram = DurationHistogram(name: "my_histogram", attributes: [], buckets: [
            .milliseconds(100),
            .milliseconds(250),
            .milliseconds(500),
            .seconds(1),
        ])

        histogram.assertStateEquals(count: 0, sum: .zero, buckets: [
            (bound: .milliseconds(100), count: 0),
            (bound: .milliseconds(250), count: 0),
            (bound: .milliseconds(500), count: 0),
            (bound: .seconds(1), count: 0),
        ], countAboveUpperBound: 0)

        histogram.record(.milliseconds(400))
        histogram.assertStateEquals(count: 1, sum: .milliseconds(400), buckets: [
            (bound: .milliseconds(100), count: 0),
            (bound: .milliseconds(250), count: 0),
            (bound: .milliseconds(500), count: 1),
            (bound: .seconds(1), count: 0),
        ], countAboveUpperBound: 0)

        histogram.record(.milliseconds(600))
        histogram.assertStateEquals(count: 2, sum: .milliseconds(1000), buckets: [
            (bound: .milliseconds(100), count: 0),
            (bound: .milliseconds(250), count: 0),
            (bound: .milliseconds(500), count: 1),
            (bound: .seconds(1), count: 1),
        ], countAboveUpperBound: 0)

        histogram.record(.milliseconds(1200))
        histogram.assertStateEquals(count: 3, sum: .milliseconds(2200), buckets: [
            (bound: .milliseconds(100), count: 0),
            (bound: .milliseconds(250), count: 0),
            (bound: .milliseconds(500), count: 1),
            (bound: .seconds(1), count: 1),
        ], countAboveUpperBound: 1)

        histogram.record(.milliseconds(80))
        histogram.assertStateEquals(count: 4, sum: .milliseconds(2280), buckets: [
            (bound: .milliseconds(100), count: 1),
            (bound: .milliseconds(250), count: 0),
            (bound: .milliseconds(500), count: 1),
            (bound: .seconds(1), count: 1),
        ], countAboveUpperBound: 1)
    }

    func test_record_concurrent() async {
        let histogram = DurationHistogram(name: "my_histogram", attributes: [], buckets: [
            .milliseconds(500),
            .milliseconds(700),
        ])
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
        histogram.assertStateEquals(count: 200_000, sum: .seconds(100_000), buckets: [
            (bound: .milliseconds(500), count: 100_000),
            (bound: .milliseconds(700), count: 100_000),
        ], countAboveUpperBound: 0)
    }

    func test_bucketRepresentation_duration() {
        for (duration, expectedBucketRepresentation) in [
            .zero: 0.0,
            .seconds(1): 1.0,
            .milliseconds(500): 0.5,
            .milliseconds(250): 0.25,
            .nanoseconds(1): 1e-9,
            Duration(secondsComponent: 0, attosecondsComponent: 1): 1e-18,
            .seconds(2) + Duration(secondsComponent: 0, attosecondsComponent: 1): 2 + 1e-18,
        ] {
            XCTAssertEqual(duration.bucketRepresentation, expectedBucketRepresentation)
        }
    }

    func test_bucketRepresentation_double() {
        for value in [
            .zero,
            .greatestFiniteMagnitude,
            .infinity,
            .leastNonzeroMagnitude,
            .leastNormalMagnitude,
            .pi,
            .ulpOfOne,
            1.2,
            -2.1,
        ] {
            XCTAssertEqual(value.bucketRepresentation, value)
        }
        XCTAssert(Double.nan.bucketRepresentation.isNaN)
        XCTAssert(Double.signalingNaN.bucketRepresentation.isSignalingNaN)
    }
}

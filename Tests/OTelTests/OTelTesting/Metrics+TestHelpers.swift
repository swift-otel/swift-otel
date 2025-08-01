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

#if canImport(XCTest)
@testable import OTel
import XCTest

extension Counter {
    var atomicValue: Int64 { atomic.load(ordering: .relaxed) }
}

extension FloatingPointCounter {
    var atomicValue: Double { Double(bitPattern: atomic.load(ordering: .relaxed)) }
}

extension Gauge {
    var atomicValue: Double { Double(bitPattern: atomic.load(ordering: .relaxed)) }
}

extension Histogram {
    private struct EquatableBucket: Equatable {
        var bound: Value
        var count: Int
    }

    func assertStateEquals(
        count: Int,
        sum: Value,
        buckets: [(bound: Value, count: Int)],
        countAboveUpperBound: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let state = box.withLockedValue { $0 }
        XCTAssertEqual(state.count, count, "Unexpected count", file: file, line: line)
        XCTAssertEqual(state.sum, sum, "Unexpected sum", file: file, line: line)
        XCTAssertEqual(
            state.buckets.map { EquatableBucket(bound: $0.bound, count: $0.count) },
            buckets.map { EquatableBucket(bound: $0.bound, count: $0.count) },
            "Unexpected buckets",
            file: file, line: line
        )
        XCTAssertEqual(state.countAboveUpperBound, countAboveUpperBound, "Unexpected countAboveUpperBound", file: file, line: line)
    }
}

extension OTelMetricPoint.OTelMetricData {
    var asSum: OTelSum? {
        guard case .sum(let sum) = data else { return nil }
        return sum
    }

    var asGauge: OTelGauge? {
        guard case .gauge(let gauge) = data else { return nil }
        return gauge
    }

    var asHistogram: OTelHistogram? {
        guard case .histogram(let histogram) = data else { return nil }
        return histogram
    }

    func assertIsCumulativeSumWithOneValue(_ value: OTelNumberDataPoint.Value, file: StaticString = #filePath, line: UInt = #line) {
        guard
            case .sum(let sum) = data,
            sum.monotonic,
            sum.aggregationTemporality == .cumulative,
            sum.points.count == 1,
            let point = sum.points.first
        else {
            XCTFail("Not cumulative sum with one point: \(self)", file: file, line: line)
            return
        }
        XCTAssertEqual(point.value, value, file: file, line: line)
    }

    func assertIsGaugeWithOneValue(_ value: OTelNumberDataPoint.Value, file: StaticString = #filePath, line: UInt = #line) {
        guard
            case .gauge(let gauge) = data,
            gauge.points.count == 1,
            let point = gauge.points.first
        else {
            XCTFail("Not gauge with one point: \(self)", file: file, line: line)
            return
        }
        XCTAssertEqual(point.value, value, file: file, line: line)
    }

    func assertIsCumulativeHistogramWith(count: Int, sum: Double, buckets: [OTelHistogramDataPoint.Bucket], file: StaticString = #filePath, line: UInt = #line) {
        guard
            case .histogram(let histogram) = data,
            histogram.aggregationTemporality == .cumulative,
            histogram.points.count == 1,
            let point = histogram.points.first
        else {
            XCTFail("Not cumulative histogram with one point: \(self)", file: file, line: line)
            return
        }

        XCTAssertEqual(point.count, UInt64(count), file: file, line: line)
        XCTAssertEqual(point.sum, sum, file: file, line: line)
        XCTAssertEqual(point.buckets, buckets, file: file, line: line)
    }
}
#endif

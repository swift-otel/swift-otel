//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2026 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import OTel
import Tracing
import XCTest

final class ExponentialHistogramMeasurementTests: XCTestCase {
    func test_measure_cumulative_returnsFullState() throws {
        let h = ValueExponentialHistogram(name: "test", maxSize: 4, maxScale: 20, temporality: .cumulative)
        h.record(1.0)
        h.record(2.0)
        h.record(4.0)

        let point = h.measure(instant: DefaultTracerClock.now)
        let histogram = try XCTUnwrap(point.data.asExponentialHistogram)
        let dp = try XCTUnwrap(histogram.points.first)
        XCTAssertEqual(dp.count, 3)
        XCTAssertEqual(dp.sum, 7.0)
        XCTAssertEqual(dp.min, 1.0)
        XCTAssertEqual(dp.max, 4.0)
        XCTAssertEqual(dp.scale, 0)
        XCTAssertEqual(dp.positive.offset, -1)
        XCTAssertEqual(dp.positive.bucketCounts, [1, 1, 1])
        XCTAssertEqual(dp.zeroCount, 0)

        let dp2 = try XCTUnwrap(h.measure(instant: DefaultTracerClock.now).data.asExponentialHistogram?.points.first)
        XCTAssertEqual(dp2.count, 3)
    }

    func test_measure_delta_resetsState() throws {
        let h = ValueExponentialHistogram(name: "test", maxSize: 160, temporality: .delta)
        h.record(1.0)
        h.record(2.0)
        h.record(4.0)

        let dp1 = try XCTUnwrap(h.measure(instant: DefaultTracerClock.now).data.asExponentialHistogram?.points.first)
        XCTAssertEqual(dp1.count, 3)
        XCTAssertEqual(dp1.sum, 7.0)

        let dp2 = try XCTUnwrap(h.measure(instant: DefaultTracerClock.now).data.asExponentialHistogram?.points.first)
        XCTAssertEqual(dp2.count, 0)
        XCTAssertNil(dp2.sum)
        XCTAssertNil(dp2.min)
        XCTAssertNil(dp2.max)
    }

    func test_measure_zeroValues() throws {
        let h = ValueExponentialHistogram(name: "test", maxSize: 160)
        h.record(0.0)
        h.record(0.0)
        h.record(1.0)

        let dp = try XCTUnwrap(h.measure(instant: DefaultTracerClock.now).data.asExponentialHistogram?.points.first)
        XCTAssertEqual(dp.count, 3)
        XCTAssertEqual(dp.zeroCount, 2)
        XCTAssertEqual(dp.positive.bucketCounts.reduce(0, +), 1)
    }

    func test_measure_delta_resetsScaleToMax() throws {
        let h = ValueExponentialHistogram(name: "test", maxSize: 4, maxScale: 20, temporality: .delta)
        h.record(1.0)
        h.record(2.0)
        h.record(4.0)

        let dp1 = try XCTUnwrap(h.measure(instant: DefaultTracerClock.now).data.asExponentialHistogram?.points.first)
        XCTAssertEqual(dp1.scale, 0)

        h.record(1.0)
        let dp2 = try XCTUnwrap(h.measure(instant: DefaultTracerClock.now).data.asExponentialHistogram?.points.first)
        XCTAssertEqual(dp2.scale, 20)
    }

    func test_measure_nameAndMetadata() {
        let h = ExponentialHistogram<Double>(
            name: "request_duration",
            unit: "s",
            description: "Request duration"
        )
        let point = h.measure()
        XCTAssertEqual(point.name, "request_duration")
        XCTAssertEqual(point.unit, "s")
        XCTAssertEqual(point.description, "Request duration")
    }

    func test_measure_durationHistogram() throws {
        let h = DurationExponentialHistogram(name: "latency", maxSize: 160)
        h.record(.milliseconds(500))
        h.record(.seconds(2))

        let dp = try XCTUnwrap(h.measure(instant: DefaultTracerClock.now).data.asExponentialHistogram?.points.first)
        XCTAssertEqual(dp.count, 2)
        XCTAssertEqual(dp.sum, 2.5)
        XCTAssertEqual(dp.min, 0.5)
        XCTAssertEqual(dp.max, 2.0)
    }
}

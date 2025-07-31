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

final class OTelMetricRegistryProducerTests: XCTestCase {
    func test_produce_noMetrics_returnsNoPoints() {
        let registry = OTelMetricRegistry()
        XCTAssertEqual(registry.produce().count, 0)
    }

    func test_produce_returnsOnePointPerRegisteredInstrument() {
        let registry = OTelMetricRegistry()

        XCTAssertEqual(registry.produce().count, 0)

        let counter = registry.makeCounter(name: "c")
        XCTAssertEqual(registry.produce().count, 1)
        counter.increment()
        XCTAssertEqual(registry.produce().count, 1)
        counter.increment(by: 3)
        XCTAssertEqual(registry.produce().count, 1)
        counter.increment(by: 42)
        XCTAssertEqual(registry.produce().count, 1)
        registry.unregisterCounter(counter)
        XCTAssertEqual(registry.produce().count, 0)

        let floatingPointCounter = registry.makeFloatingPointCounter(name: "f")
        XCTAssertEqual(registry.produce().count, 1)
        floatingPointCounter.increment()
        XCTAssertEqual(registry.produce().count, 1)
        floatingPointCounter.increment(by: 3.14)
        XCTAssertEqual(registry.produce().count, 1)
        floatingPointCounter.increment(by: 42)
        XCTAssertEqual(registry.produce().count, 1)
        registry.unregisterFloatingPointCounter(floatingPointCounter)
        XCTAssertEqual(registry.produce().count, 0)

        let gauge = registry.makeGauge(name: "g")
        XCTAssertEqual(registry.produce().count, 1)
        gauge.set(1.0)
        XCTAssertEqual(registry.produce().count, 1)
        gauge.set(to: 3.14)
        XCTAssertEqual(registry.produce().count, 1)
        gauge.set(Int64(42))
        XCTAssertEqual(registry.produce().count, 1)
        registry.unregisterGauge(gauge)
        XCTAssertEqual(registry.produce().count, 0)

        let valueHistogram = registry.makeValueHistogram(name: "v", buckets: [])
        XCTAssertEqual(registry.produce().count, 1)
        valueHistogram.record(1.0)
        XCTAssertEqual(registry.produce().count, 1)
        valueHistogram.record(Int64(42))
        XCTAssertEqual(registry.produce().count, 1)
        registry.unregisterValueHistogram(valueHistogram)
        XCTAssertEqual(registry.produce().count, 0)

        let durationHistogram = registry.makeDurationHistogram(name: "d", buckets: [])
        XCTAssertEqual(registry.produce().count, 1)
        durationHistogram.record(.seconds(1))
        XCTAssertEqual(registry.produce().count, 1)
        durationHistogram.record(.milliseconds(42))
        XCTAssertEqual(registry.produce().count, 1)
        durationHistogram.recordNanoseconds(1234)
        XCTAssertEqual(registry.produce().count, 1)
        registry.unregisterDurationHistogram(durationHistogram)
        XCTAssertEqual(registry.produce().count, 0)
    }
}

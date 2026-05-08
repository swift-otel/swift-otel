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
import XCTest

final class ExponentialHistogramTests: XCTestCase {
    // MARK: - Bucket index at known scales

    func test_bucketIndex_scale0_powersOfTwo() {
        XCTAssertEqual(ExponentialHistogram<Double>.bucketIndex(for: 1.0, scale: 0), -1)
        XCTAssertEqual(ExponentialHistogram<Double>.bucketIndex(for: 2.0, scale: 0), 0)
        XCTAssertEqual(ExponentialHistogram<Double>.bucketIndex(for: 4.0, scale: 0), 1)
        XCTAssertEqual(ExponentialHistogram<Double>.bucketIndex(for: 8.0, scale: 0), 2)
        XCTAssertEqual(ExponentialHistogram<Double>.bucketIndex(for: 16.0, scale: 0), 3)
    }

    func test_bucketIndex_scale0_nonPowersOfTwo() {
        XCTAssertEqual(ExponentialHistogram<Double>.bucketIndex(for: 3.0, scale: 0), 1)
        XCTAssertEqual(ExponentialHistogram<Double>.bucketIndex(for: 5.0, scale: 0), 2)
    }

    func test_bucketIndex_negativeScale() {
        XCTAssertEqual(ExponentialHistogram<Double>.bucketIndex(for: 1.0, scale: -1), -1)
        XCTAssertEqual(ExponentialHistogram<Double>.bucketIndex(for: 2.0, scale: -1), 0)
        XCTAssertEqual(ExponentialHistogram<Double>.bucketIndex(for: 4.0, scale: -1), 0)
        XCTAssertEqual(ExponentialHistogram<Double>.bucketIndex(for: 5.0, scale: -1), 1)
        XCTAssertEqual(ExponentialHistogram<Double>.bucketIndex(for: 16.0, scale: -1), 1)
    }

    func test_bucketIndex_scale20_extremeValues() {
        XCTAssertEqual(
            ExponentialHistogram<Double>.bucketIndex(for: Double.greatestFiniteMagnitude, scale: 20),
            1_073_741_823
        )
        XCTAssertEqual(
            ExponentialHistogram<Double>.bucketIndex(for: Double.leastNonzeroMagnitude, scale: 20),
            -1_126_170_625
        )
    }

    // MARK: - Scale change detection

    func test_scaleChange_emptyBucket_noChangeNeeded() {
        let result = ExponentialHistogram<Double>.scaleChange(bin: 5, startBin: 0, length: 0, maxSize: 4)
        XCTAssertEqual(result, 0)
    }

    func test_scaleChange_binInRange_noChangeNeeded() {
        let result = ExponentialHistogram<Double>.scaleChange(bin: 5, startBin: -1, length: 10, maxSize: 20)
        XCTAssertEqual(result, 0)
    }

    func test_scaleChange_binBelowStart_needsRescale() {
        let result = ExponentialHistogram<Double>.scaleChange(bin: 5, startBin: 8, length: 3, maxSize: 5)
        XCTAssertEqual(result, 1)
    }

    func test_scaleChange_binAboveEnd_needsRescale() {
        let result = ExponentialHistogram<Double>.scaleChange(bin: 7, startBin: 2, length: 3, maxSize: 5)
        XCTAssertEqual(result, 1)
    }

    func test_scaleChange_largeGap_needsMultipleRescales() {
        let result = ExponentialHistogram<Double>.scaleChange(bin: 13, startBin: 2, length: 3, maxSize: 5)
        XCTAssertEqual(result, 2)
    }

    func test_scaleChange_maxSizeOne_returnsMaxDelta() {
        let result = ExponentialHistogram<Double>.scaleChange(bin: 1, startBin: -1, length: 1, maxSize: 1)
        XCTAssertEqual(result, 31)
    }

    // MARK: - Record: integrated behavior

    func test_record_maxSize4_downscalesToScale0() {
        let h = ValueExponentialHistogram(name: "test", maxSize: 4, maxScale: 20)
        for v in [2.0, 4.0, 1.0] {
            h.record(v)
            h.record(-v)
        }
        let state = h.box.withLockedValue { $0 }
        XCTAssertEqual(state.scale, 0)
        XCTAssertEqual(state.positive, ExpoBuckets(startBin: -1, counts: [1, 1, 1]))
        XCTAssertEqual(state.negative, ExpoBuckets(startBin: -1, counts: [1, 1, 1]))
    }

    func test_record_maxSize2_downscalesToNegativeScale() {
        let h = ValueExponentialHistogram(name: "test", maxSize: 2, maxScale: 20)
        for v in [1.0, 2.0, 4.0] {
            h.record(v)
            h.record(-v)
        }
        let state = h.box.withLockedValue { $0 }
        XCTAssertEqual(state.scale, -1)
        XCTAssertEqual(state.positive, ExpoBuckets(startBin: -1, counts: [1, 2]))
        XCTAssertEqual(state.negative, ExpoBuckets(startBin: -1, counts: [1, 2]))
    }

    func test_record_maxSize4_withDuplicates() {
        let h = ValueExponentialHistogram(name: "test", maxSize: 4, maxScale: 20)
        for v in [4.0, 4.0, 4.0, 2.0, 16.0, 1.0] {
            h.record(v)
            h.record(-v)
        }
        let state = h.box.withLockedValue { $0 }
        XCTAssertEqual(state.scale, -1)
        XCTAssertEqual(state.positive, ExpoBuckets(startBin: -1, counts: [1, 4, 1]))
        XCTAssertEqual(state.negative, ExpoBuckets(startBin: -1, counts: [1, 4, 1]))
    }

    // MARK: - Scale underflow

    func test_record_scaleUnderflow_dropsValueEntirely() {
        let h = ValueExponentialHistogram(name: "test", maxSize: 1, maxScale: 20)
        h.record(1.0)
        h.record(1_000_000.0)

        let state = h.box.withLockedValue { $0 }
        XCTAssertEqual(state.sum, 1.0)
        XCTAssertEqual(state.min, 1.0)
        XCTAssertEqual(state.max, 1.0)
        XCTAssertEqual(state.positive.totalCount, 1)
    }

    // MARK: - NaN and infinity are silently ignored

    func test_record_nanAndInfinity_ignored() {
        let h = ValueExponentialHistogram(name: "test", maxSize: 4, maxScale: 20)
        h.record(1.0)
        h.record(Double.nan)
        h.record(Double.signalingNaN)
        h.record(Double.infinity)
        h.record(-Double.infinity)
        let state = h.box.withLockedValue { $0 }
        XCTAssertEqual(state.sum, 1.0)
        XCTAssertEqual(state.positive.totalCount, 1)
    }

    // MARK: - Zero handling

    func test_record_zero_incrementsZeroCount() {
        let h = ValueExponentialHistogram(name: "test", maxSize: 4, maxScale: 20)
        h.record(0.0)
        h.record(0.0)
        h.record(0.0)
        let state = h.box.withLockedValue { $0 }
        XCTAssertEqual(state.zeroCount, 3)
        XCTAssertEqual(state.positive.totalCount, 0)
        XCTAssertEqual(state.negative.totalCount, 0)
    }

    // MARK: - Sum, min, max

    func test_record_sumMinMax() {
        let h = ValueExponentialHistogram(name: "test", maxSize: 4, maxScale: 20)
        h.record(2.0)
        h.record(4.0)
        h.record(1.0)
        let state = h.box.withLockedValue { $0 }
        XCTAssertEqual(state.sum, 7.0)
        XCTAssertEqual(state.min, 1.0)
        XCTAssertEqual(state.max, 4.0)
    }

    func test_record_negativeValues_sumMinMax() {
        let h = ValueExponentialHistogram(name: "test", maxSize: 4, maxScale: 20)
        h.record(-3.0)
        h.record(-1.0)
        h.record(2.0)
        let state = h.box.withLockedValue { $0 }
        XCTAssertEqual(state.sum, -2.0)
        XCTAssertEqual(state.min, -3.0)
        XCTAssertEqual(state.max, 2.0)
    }

    // MARK: - Concurrency

    func test_record_concurrent() async {
        let h = ValueExponentialHistogram(name: "test", maxSize: 160, maxScale: 20)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 100_000 {
                group.addTask { h.record(1.0) }
            }
            for _ in 0 ..< 100_000 {
                group.addTask { h.record(-1.0) }
            }
        }
        let state = h.box.withLockedValue { $0 }
        XCTAssertEqual(state.positive.totalCount + state.negative.totalCount, 200_000)
        XCTAssertEqual(state.sum, 0.0, accuracy: 1e-9)
    }
}

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

final class ExpoBucketsTests: XCTestCase {
    // MARK: - record: totalCount invariant

    func test_record_incrementsTotalCountByOne() {
        var b = ExpoBuckets()
        for i: Int32 in 0 ..< 10 {
            b.record(i)
            XCTAssertEqual(b.totalCount, UInt64(i + 1))
        }
    }

    func test_record_repeatedSameBin_accumulates() {
        var b = ExpoBuckets()
        b.record(3)
        b.record(3)
        b.record(3)
        XCTAssertEqual(b.counts, [3])
        XCTAssertEqual(b.startBin, 3)
    }

    // MARK: - record: empty bucket

    func test_record_empty_establishesStartBin() {
        var b = ExpoBuckets()
        b.record(-5)
        XCTAssertEqual(b.startBin, -5)
        XCTAssertEqual(b.counts, [1])
    }

    // MARK: - record: in-range (no expansion)

    func test_record_inRange_onlyTargetBinChanges() {
        var b = ExpoBuckets(startBin: 3, counts: [1, 2, 3, 4, 5, 6])
        let countBefore = b.totalCount
        b.record(5)
        XCTAssertEqual(b.startBin, 3)
        XCTAssertEqual(b.counts, [1, 2, 4, 4, 5, 6])
        XCTAssertEqual(b.totalCount, countBefore + 1)
    }

    // MARK: - record: prepend (expand left)

    func test_record_prepend_expandsWithZeros() {
        var b = ExpoBuckets(startBin: 1, counts: [1, 2, 3, 4, 5, 6])
        b.record(-2)
        XCTAssertEqual(b.startBin, -2)
        XCTAssertEqual(b.counts, [1, 0, 0, 1, 2, 3, 4, 5, 6])
    }

    // MARK: - record: append (expand right)

    func test_record_append_expandsWithZeros() {
        var b = ExpoBuckets(startBin: -2, counts: [1, 2, 3, 4, 5, 6])
        b.record(4)
        XCTAssertEqual(b.startBin, -2)
        XCTAssertEqual(b.counts, [1, 2, 3, 4, 5, 6, 1])
    }

    // MARK: - downscale: totalCount preservation

    func test_downscale_preservesTotalCount() {
        let cases: [(startBin: Int32, counts: [UInt64], delta: Int32)] = [
            (0, [1, 2, 3, 4, 5, 6], 1),
            (0, [1, 2, 3, 4, 5, 6], 2),
            (0, [1, 2, 3, 4, 5, 6], 3),
            (5, [1, 2, 3, 4, 5, 6], 1),
            (7, [1, 2, 3, 4, 5, 6], 2),
            (-4, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 1),
            (-1, [1, 0, 3], 1),
        ]
        for (startBin, counts, delta) in cases {
            var b = ExpoBuckets(startBin: startBin, counts: counts)
            let countBefore = b.totalCount
            b.downscale(by: delta)
            XCTAssertEqual(
                b.totalCount, countBefore,
                "totalCount changed for startBin=\(startBin), counts=\(counts), delta=\(delta)"
            )
        }
    }

    // MARK: - downscale: composability

    func test_downscale_composable_twoByOneEqualsByTwo() {
        var stepwise = ExpoBuckets(startBin: 0, counts: [1, 2, 3, 4, 5, 6, 7, 8])
        stepwise.downscale(by: 1)
        stepwise.downscale(by: 1)

        var direct = ExpoBuckets(startBin: 0, counts: [1, 2, 3, 4, 5, 6, 7, 8])
        direct.downscale(by: 2)

        XCTAssertEqual(stepwise, direct)
    }

    func test_downscale_composable_unaligned() {
        var stepwise = ExpoBuckets(startBin: 3, counts: [1, 2, 3, 4, 5, 6, 7, 8])
        stepwise.downscale(by: 1)
        stepwise.downscale(by: 1)

        var direct = ExpoBuckets(startBin: 3, counts: [1, 2, 3, 4, 5, 6, 7, 8])
        direct.downscale(by: 2)

        XCTAssertEqual(stepwise, direct)
    }

    // MARK: - downscale: boundary conditions

    func test_downscale_empty_noOp() {
        var b = ExpoBuckets()
        b.downscale(by: 3)
        XCTAssertEqual(b, ExpoBuckets())
    }

    func test_downscale_singleBucket_onlyShiftsStartBin() {
        var b = ExpoBuckets(startBin: 50, counts: [7])
        b.downscale(by: 4)
        XCTAssertEqual(b.startBin, 3)
        XCTAssertEqual(b.counts, [7])
    }

    func test_downscale_deltaZero_noOp() {
        var b = ExpoBuckets(startBin: 50, counts: [7, 5])
        b.downscale(by: 0)
        XCTAssertEqual(b.startBin, 50)
        XCTAssertEqual(b.counts, [7, 5])
    }

    // MARK: - downscale: negative startBin (modular arithmetic)

    func test_downscale_negativeStartBin() {
        var b = ExpoBuckets(startBin: -1, counts: [1, 0, 3])
        b.downscale(by: 1)
        XCTAssertEqual(b.startBin, -1)
        XCTAssertEqual(b.counts, [1, 3])
    }

    func test_downscale_negativeStartBin_long() {
        var b = ExpoBuckets(startBin: -4, counts: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        b.downscale(by: 1)
        XCTAssertEqual(b.startBin, -2)
        XCTAssertEqual(b.counts, [3, 7, 11, 15, 19])
    }

    // MARK: - downscale: unaligned startBin (offset != 0)

    func test_downscale_unaligned_scale1() {
        var b = ExpoBuckets(startBin: 5, counts: [1, 2, 3, 4, 5, 6])
        b.downscale(by: 1)
        XCTAssertEqual(b.startBin, 2)
        XCTAssertEqual(b.counts, [1, 5, 9, 6])
    }

    func test_downscale_unaligned_scale2() {
        var b = ExpoBuckets(startBin: 7, counts: [1, 2, 3, 4, 5, 6])
        b.downscale(by: 2)
        XCTAssertEqual(b.startBin, 1)
        XCTAssertEqual(b.counts, [1, 14, 6])
    }

    // MARK: - downscale: aligned startBin (reference vectors)

    func test_downscale_aligned_scale1() {
        var b = ExpoBuckets(startBin: 0, counts: [1, 2, 3, 4, 5, 6])
        b.downscale(by: 1)
        XCTAssertEqual(b.startBin, 0)
        XCTAssertEqual(b.counts, [3, 7, 11])
    }

    func test_downscale_aligned_scale2() {
        var b = ExpoBuckets(startBin: 0, counts: [1, 2, 3, 4, 5, 6])
        b.downscale(by: 2)
        XCTAssertEqual(b.startBin, 0)
        XCTAssertEqual(b.counts, [10, 11])
    }

    func test_downscale_aligned_scale3() {
        var b = ExpoBuckets(startBin: 0, counts: [1, 2, 3, 4, 5, 6])
        b.downscale(by: 3)
        XCTAssertEqual(b.startBin, 0)
        XCTAssertEqual(b.counts, [21])
    }
}

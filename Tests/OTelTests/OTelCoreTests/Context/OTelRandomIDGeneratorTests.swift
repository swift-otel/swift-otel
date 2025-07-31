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

import OTelCore
import W3CTraceContext
import XCTest

final class OTelRandomIDGeneratorTests: XCTestCase {
    func test_traceID_witConstantNumberGenerator_returnsConstantTraceID() {
        let generator = OTelRandomIDGenerator(randomNumberGenerator: ConstantNumberGenerator(value: .max))

        XCTAssertEqual(
            generator.nextTraceID(),
            TraceID(bytes: .init((255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255)))
        )
    }

    func test_traceID_withConstantNumberGenerator_withRandomNumber_returnsRandomTraceID() {
        let randomValue = UInt64.random(in: .min ..< .max)

        let generator = OTelRandomIDGenerator(randomNumberGenerator: ConstantNumberGenerator(value: randomValue))
        let traceID = generator.nextTraceID()

        let randomHexString = String(randomValue, radix: 16, uppercase: false)
        let pad = String(repeating: "0", count: 16 - randomHexString.count)
        let paddedHexString = "\(pad)\(randomHexString)"

        XCTAssertEqual(traceID.description, paddedHexString + paddedHexString)
    }

    func test_traceID_withSystemRandomNumberGenerator_returnsRandomTraceIDs() {
        let generator = OTelRandomIDGenerator()
        var traceIDs = Set<TraceID>()

        for _ in 0 ..< 1000 {
            let (inserted, traceID) = traceIDs.insert(generator.nextTraceID())

            XCTAssertTrue(inserted, "Expected unique trace IDs, got duplicate: \(traceID)")
        }
    }

    func test_spanID_witConstantNumberGenerator_returnsConstantSpanID() {
        let generator = OTelRandomIDGenerator(randomNumberGenerator: ConstantNumberGenerator(value: .max))

        XCTAssertEqual(generator.nextSpanID(), SpanID(bytes: .init((255, 255, 255, 255, 255, 255, 255, 255))))
    }

    func test_spanID_withConstantNumberGenerator_withRandomNumber_returnsRandomSpanID() {
        let randomValue = UInt64.random(in: .min ..< .max)

        let generator = OTelRandomIDGenerator(randomNumberGenerator: ConstantNumberGenerator(value: randomValue))
        let spanID = generator.nextSpanID()

        let randomHexString = String(randomValue, radix: 16, uppercase: false)
        let pad = String(repeating: "0", count: 16 - randomHexString.count)
        let paddedHexString = "\(pad)\(randomHexString)"

        XCTAssertEqual(spanID.description, paddedHexString)
    }

    func test_spanID_withSystemRandomNumberGenerator_returnsRandomSpanIDs() {
        let generator = OTelRandomIDGenerator()
        var spanIDs = Set<SpanID>()

        for _ in 0 ..< 1000 {
            let (inserted, spanID) = spanIDs.insert(generator.nextSpanID())

            XCTAssertTrue(inserted, "Expected unique span IDs, got duplicate: \(spanID)")
        }
    }
}

// MARK: - Helpers

private struct ConstantNumberGenerator: RandomNumberGenerator {
    let value: UInt64

    func next() -> UInt64 {
        value
    }
}

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2025 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import OTelCore
import Testing
import W3CTraceContext

@Suite
struct OTelXRayIDGeneratorTests {
    @Test func generatesRandomTraceID() async throws {
        let idGenerator = OTelXRayIDGenerator(
            randomNumberGenerator: ConstantNumberGenerator(value: .max),
            getCurrentSecondsSinceEpoch: { 1_616_064_590 }
        )

        let generatedTraceID = idGenerator.nextTraceID()
        let expectedTraceID = TraceID(
            bytes: .init((96, 83, 48, 78, 255, 255, 255, 254, 255, 255, 255, 255, 255, 255, 255, 254))
        )

        #expect(generatedTraceID == expectedTraceID)
    }

    @Test func generatesRandomTraceID_withRandomNumberGenerator() {
        let idGenerator = OTelXRayIDGenerator(
            randomNumberGenerator: ConstantNumberGenerator(value: .random(in: 0 ..< .max)),
            getCurrentSecondsSinceEpoch: { 1_616_064_590 }
        )

        let randomTraceID = idGenerator.nextTraceID()

        #expect(
            randomTraceID.description.starts(with: "6053304e"),
            "X-Ray trace ids must start with the current timestamp."
        )
    }

    @Test func generatesUniqueTraceIDs() {
        let idGenerator = OTelXRayIDGenerator()
        var traceIDs = Set<TraceID>()

        for _ in 0 ..< 1000 {
            traceIDs.insert(idGenerator.nextTraceID())
        }

        #expect(traceIDs.count == 1000, "Generating 1000 X-Ray trace ids should result in 1000 unique trace ids.")
    }

    @Test func generatesRandomSpanID() {
        let idGenerator = OTelXRayIDGenerator(
            randomNumberGenerator: ConstantNumberGenerator(value: .max),
            getCurrentSecondsSinceEpoch: { 0 }
        )

        let generatedSpanID = idGenerator.nextSpanID()
        let expectedSpanID = SpanID(bytes: .init((255, 255, 255, 255, 255, 255, 255, 255)))

        #expect(generatedSpanID == expectedSpanID)
    }

    @Test func generatesRandomSpanID_withRandomNumberGenerator() {
        let randomValue = UInt64.random(in: 0 ..< .max)
        let randomHexString = String(randomValue, radix: 16, uppercase: false)
        let hexString = randomHexString.count == 16 ? randomHexString : "0\(randomHexString)"
        let idGenerator = OTelXRayIDGenerator(
            randomNumberGenerator: ConstantNumberGenerator(value: randomValue),
            getCurrentSecondsSinceEpoch: { 0 }
        )

        let randomSpanID = idGenerator.nextSpanID()

        #expect(randomSpanID.description == hexString)
    }

    @Test func generatesUniqueSpanIDs() {
        let idGenerator = OTelXRayIDGenerator()
        var spanIDs = Set<SpanID>()

        for _ in 0 ..< 1000 {
            spanIDs.insert(idGenerator.nextSpanID())
        }

        #expect(spanIDs.count == 1000, "Generating 1000 X-Ray span ids should result in 1000 unique span ids.")
    }
}

// MARK: - Helpers

private struct ConstantNumberGenerator: RandomNumberGenerator {
    let value: UInt64

    func next() -> UInt64 {
        value
    }
}

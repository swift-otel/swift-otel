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

import NIOConcurrencyHelpers
import Tracing

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// An exponential histogram to record timings.
typealias DurationExponentialHistogram = ExponentialHistogram<Duration>
/// An exponential histogram to record floating point values.
typealias ValueExponentialHistogram = ExponentialHistogram<Double>

let expoMaxScale: Int32 = 20
let expoMinScale: Int32 = -10
let expoDefaultMaxSize: Int = 160

/// Pre-computed scale factors: `scaleFactors[s] = log2(e) * 2^s`.
private let scaleFactors: [Double] = (0 ... 20).map {
    Double(sign: .plus, exponent: $0, significand: M_LOG2E)
}

/// A histogram with exponentially-growing bucket boundaries that auto-scales
/// to maintain constant relative precision across all magnitudes.
///
/// - SeeAlso: [OTel Exponential Histogram](https://opentelemetry.io/docs/specs/otel/metrics/data-model/#exponentialhistogram)
final class ExponentialHistogram<Value: Bucketable>: Sendable {
    let name: String
    let unit: String?
    let description: String?
    let attributes: Set<Attribute>
    let temporality: OTelAggregationTemporality
    let maxSize: Int
    let maxScale: Int32
    let emptyState: State

    struct State: Sendable {
        var scale: Int32
        var positive: ExpoBuckets
        var negative: ExpoBuckets
        var zeroCount: UInt64
        var sum: Double
        var min: Double?
        var max: Double?
        var startTimeNanoseconds: UInt64
    }

    let box: NIOLockedValueBox<State>

    init(
        name: String,
        unit: String? = nil,
        description: String? = nil,
        attributes: Set<Attribute> = [],
        maxSize: Int = expoDefaultMaxSize,
        maxScale: Int32 = expoMaxScale,
        temporality: OTelAggregationTemporality = .cumulative
    ) {
        precondition(maxSize >= 1, "maxSize must be at least 1")
        precondition(maxScale >= expoMinScale && maxScale <= expoMaxScale, "maxScale must be in \(expoMinScale)...\(expoMaxScale)")
        self.name = name
        self.unit = unit
        self.description = description
        self.attributes = attributes
        self.maxSize = maxSize
        self.maxScale = maxScale
        self.temporality = temporality
        let initialState = State(
            scale: maxScale,
            positive: ExpoBuckets(),
            negative: ExpoBuckets(),
            zeroCount: 0,
            sum: 0,
            min: nil,
            max: nil,
            startTimeNanoseconds: DefaultTracerClock.now.nanosecondsSinceEpoch
        )
        emptyState = initialState
        box = .init(initialState)
    }

    convenience init(
        name: String,
        unit: String? = nil,
        description: String? = nil,
        attributes: [(String, String)],
        maxSize: Int = expoDefaultMaxSize,
        maxScale: Int32 = expoMaxScale,
        temporality: OTelAggregationTemporality = .cumulative
    ) {
        self.init(
            name: name,
            unit: unit,
            description: description,
            attributes: Set(attributes),
            maxSize: maxSize,
            maxScale: maxScale,
            temporality: temporality
        )
    }

    func record(_ value: Value) {
        let doubleValue = value.bucketRepresentation

        guard doubleValue.isFinite else { return }

        box.withLockedValue { state in
            let absValue = Swift.abs(doubleValue)
            if absValue == 0 {
                state.sum += doubleValue
                state.min = state.min.map { Swift.min($0, doubleValue) } ?? doubleValue
                state.max = state.max.map { Swift.max($0, doubleValue) } ?? doubleValue
                state.zeroCount += 1
                return
            }

            var bin = Self.bucketIndex(for: absValue, scale: state.scale)

            let isPositive = doubleValue > 0
            let targetStartBin = isPositive ? state.positive.startBin : state.negative.startBin
            let targetLength = isPositive ? state.positive.length : state.negative.length

            let scaleDelta = Self.scaleChange(
                bin: bin,
                startBin: targetStartBin,
                length: targetLength,
                maxSize: maxSize
            )

            if scaleDelta > 0 {
                guard state.scale - scaleDelta >= expoMinScale else { return }
                state.scale -= scaleDelta
                state.positive.downscale(by: scaleDelta)
                state.negative.downscale(by: scaleDelta)
                bin = Self.bucketIndex(for: absValue, scale: state.scale)
            }

            state.sum += doubleValue
            state.min = state.min.map { Swift.min($0, doubleValue) } ?? doubleValue
            state.max = state.max.map { Swift.max($0, doubleValue) } ?? doubleValue

            if isPositive {
                state.positive.record(bin)
            } else {
                state.negative.record(bin)
            }
        }
    }

    // MARK: - Bucket index calculation

    /// Maps a positive value to a bucket index at the given scale.
    ///
    /// - Coarse scales (≤ 0): bit-shift the IEEE 754 exponent.
    /// - Fine scales (> 0): logarithm with pre-computed factor.
    static func bucketIndex(for value: Double, scale: Int32) -> Int32 {
        var exp = Int32(0)
        let frac = frexp(value, &exp)
        if scale <= 0 {
            let correction: Int32 = (frac == 0.5) ? 2 : 1
            return (exp - correction) >> -scale
        }
        return (exp << scale) + Int32(log(frac) * scaleFactors[Int(scale)]) - 1
    }

    /// Returns how many scale levels to reduce so that `bin` fits within `maxSize`
    /// of the existing bucket range.
    static func scaleChange(bin: Int32, startBin: Int32, length: Int, maxSize: Int) -> Int32 {
        if length == 0 { return 0 }

        var low = Int(startBin)
        var high = Int(bin)
        if startBin >= bin {
            low = Int(bin)
            high = Int(startBin) + length - 1
        }

        var count: Int32 = 0
        while high - low >= maxSize {
            low >>= 1
            high >>= 1
            count += 1
            if count > expoMaxScale - expoMinScale { return count }
        }
        return count
    }
}

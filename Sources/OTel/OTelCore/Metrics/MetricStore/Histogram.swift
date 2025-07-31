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
//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftPrometheus open source project
//
// Copyright (c) 2018-2023 SwiftPrometheus project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftPrometheus project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOConcurrencyHelpers

/// A type that can be used in a ``Histogram`` to create bucket boundaries.
protocol Bucketable: AdditiveArithmetic, Comparable, Sendable {
    /// A bucket bound representation that is used in the OTLP export.
    var bucketRepresentation: Double { get }
}

/// A Histogram to record timings.
typealias DurationHistogram = Histogram<Duration>
/// A Histogram to record floating point values.
typealias ValueHistogram = Histogram<Double>

/// A generic Histogram implementation
final class Histogram<Value: Bucketable>: Sendable {
    let name: String
    let unit: String?
    let description: String?
    let attributes: Set<Attribute>

    @usableFromInline
    struct State: Sendable {
        @usableFromInline var buckets: [(bound: Value, count: Int)]
        @usableFromInline var countAboveUpperBound: Int
        @usableFromInline var sum: Value
        @usableFromInline var count: Int

        @inlinable
        init(buckets: [Value]) {
            countAboveUpperBound = 0
            sum = .zero
            count = 0
            self.buckets = buckets.map { ($0, 0) }
        }
    }

    @usableFromInline let box: NIOLockedValueBox<State>

    init(name: String, unit: String? = nil, description: String? = nil, attributes: Set<Attribute> = [], buckets: [Value]) {
        self.name = name
        self.unit = unit
        self.description = description
        self.attributes = attributes
        box = .init(.init(buckets: buckets))
    }

    convenience init(name: String, unit: String? = nil, description: String? = nil, attributes: [(String, String)] = [], buckets: [Value]) {
        self.init(name: name, unit: unit, description: description, attributes: Set(attributes), buckets: buckets)
    }

    func record(_ value: Value) {
        box.withLockedValue { state in
            state.sum += value
            state.count += 1
            if state.buckets.isEmpty {
                state.countAboveUpperBound += 1
            } else {
                var didMatchBucket = false
                for i in state.buckets.startIndex ..< state.buckets.endIndex {
                    if value <= state.buckets[i].0 {
                        state.buckets[i].1 += 1
                        didMatchBucket = true
                        break
                    }
                }
                if !didMatchBucket {
                    state.countAboveUpperBound += 1
                }
            }
        }
    }
}

extension Duration: Bucketable {
    var bucketRepresentation: Double {
        let attos = String(unsafeUninitializedCapacity: 18) { buffer in
            var num = self.components.attoseconds

            var positions = 17
            var length: Int?
            while positions >= 0 {
                defer {
                    positions -= 1
                    num = num / 10
                }
                let remainder = num % 10

                if length != nil {
                    buffer[positions] = UInt8(ascii: "0") + UInt8(remainder)
                } else {
                    if remainder == 0 {
                        continue
                    }

                    length = positions + 1
                    buffer[positions] = UInt8(ascii: "0") + UInt8(remainder)
                }
            }

            if length == nil {
                buffer[0] = UInt8(ascii: "0")
                length = 1
            }

            return length!
        }
        return Double("\(components.seconds).\(attos)")!
    }
}

extension Double: Bucketable {
    var bucketRepresentation: Double { self }
}

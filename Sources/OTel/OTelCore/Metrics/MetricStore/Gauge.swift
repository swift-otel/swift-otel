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

import Atomics

/// A gauge is a metric that represents a single numerical value that can arbitrarily go up and down.
///
/// Gauges are typically used for measured values like temperatures or current memory usage, but
/// also "counts" that can go up and down, like the number of concurrent requests.
final class Gauge: Sendable {
    let atomic = ManagedAtomic(Double.zero.bitPattern)

    let name: String
    let unit: String?
    let description: String?
    let attributes: Set<Attribute>

    init(name: String, unit: String? = nil, description: String? = nil, attributes: Set<Attribute> = []) {
        self.name = name
        self.unit = unit
        self.description = description
        self.attributes = attributes
    }

    convenience init(name: String, unit: String? = nil, description: String? = nil, attributes: [(String, String)] = []) {
        self.init(name: name, unit: unit, description: description, attributes: Set(attributes))
    }

    func set(to value: Double) {
        atomic.store(value.bitPattern, ordering: .relaxed)
    }

    func increment(by amount: Double = 1.0) {
        // We busy loop here until we can update the atomic successfully.
        // Using relaxed ordering here is sufficient, since the as-if rules guarantess that
        // the following operations are executed in the order presented here. Every statement
        // depends on the execution before.
        while true {
            let bits = atomic.load(ordering: .relaxed)
            let value = Double(bitPattern: bits) + amount
            let (exchanged, _) = atomic.compareExchange(
                expected: bits,
                desired: value.bitPattern,
                ordering: .relaxed
            )
            if exchanged {
                break
            }
        }
    }

    func decrement(by amount: Double = 1.0) {
        increment(by: -amount)
    }
}

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

/// A counter is a cumulative metric that represents a single monotonically increasing
/// counter whose value can only increase or be ``reset()`` to zero on restart.
///
/// For example, you can use a counter to represent the number of requests served, tasks completed, or errors.
///
/// Do not use a counter to expose a value that can decrease. For example, do not use a counter for the
/// number of currently running processes; instead use a ``Gauge``.
final class FloatingPointCounter: Sendable {
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

    func increment() {
        increment(by: 1)
    }

    func increment(by amount: Double) {
        precondition(amount >= 0)
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

    func reset() {
        atomic.store(Double.zero.bitPattern, ordering: .relaxed)
    }
}

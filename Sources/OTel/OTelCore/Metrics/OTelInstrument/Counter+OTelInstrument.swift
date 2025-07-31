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
import Tracing

extension Counter: OTelMetricInstrument {
    /// Return the current state as an OTel metric data point.
    ///
    /// Since our simplifed Swift Metrics backend datamodel only stores the current count, the only sensible mapping to
    /// an OTel data point we can provide is a sum, with cumulative aggregation temporality.
    func measure() -> OTelMetricPoint {
        measure(instant: DefaultTracerClock.now)
    }

    /// Return the current state as an OTel metric data point.
    ///
    /// Since our simplifed Swift Metrics backend datamodel only stores the current count, the only sensible mapping to
    /// an OTel data point we can provide is a sum, with cumulative aggregation temporality.
    func measure(instant: some TracerInstant) -> OTelMetricPoint {
        let value = atomic.load(ordering: .relaxed)
        return OTelMetricPoint(
            name: name,
            description: description ?? "",
            unit: unit ?? "",
            data: .sum(OTelSum(
                points: [.init(
                    attributes: attributes.map { OTelAttribute(key: $0.key, value: $0.value) },
                    timeNanosecondsSinceEpoch: instant.nanosecondsSinceEpoch,
                    value: .int64(value)
                )],
                aggregationTemporality: .cumulative,
                monotonic: true
            ))
        )
    }
}

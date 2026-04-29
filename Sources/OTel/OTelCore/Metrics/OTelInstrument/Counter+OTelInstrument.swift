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
    func measure() -> OTelMetricPoint {
        measure(instant: DefaultTracerClock.now)
    }

    /// Return the current state as an OTel metric data point.
    ///
    /// For cumulative temporality, reports the running total.
    /// For delta temporality, atomically reads and resets the counter,
    /// advancing the start time for the next interval.
    func measure(instant: some TracerInstant) -> OTelMetricPoint {
        let value: Int64
        let startTime: UInt64
        switch temporality.temporality {
        case .delta:
            value = atomic.exchange(0, ordering: .relaxed)
            startTime = startTimeNanoseconds.exchange(instant.nanosecondsSinceEpoch, ordering: .relaxed)
        case .cumulative:
            value = atomic.load(ordering: .relaxed)
            startTime = startTimeNanoseconds.load(ordering: .relaxed)
        }
        return OTelMetricPoint(
            name: name,
            description: description ?? "",
            unit: unit ?? "",
            data: .sum(OTelSum(
                points: [.init(
                    attributes: attributes.map { OTelAttribute(key: $0.key, value: $0.value) },
                    startTimeNanosecondsSinceEpoch: startTime,
                    timeNanosecondsSinceEpoch: instant.nanosecondsSinceEpoch,
                    value: .int64(value),
                )],
                aggregationTemporality: temporality,
                monotonic: true,
            )),
        )
    }
}

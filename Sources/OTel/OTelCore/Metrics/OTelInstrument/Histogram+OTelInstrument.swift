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

extension Histogram: OTelMetricInstrument {
    /// Return the current state as an OTel metric data point.
    func measure() -> OTelMetricPoint {
        measure(instant: DefaultTracerClock.now)
    }

    /// Return the current state as an OTel metric data point.
    ///
    /// For cumulative temporality, reports the all-time state.
    /// For delta temporality, snapshots the state, resets it, and
    /// advances the start time for the next interval.
    func measure(instant: some TracerInstant) -> OTelMetricPoint {
        let state: State = box.withLockedValue { state in
            switch temporality.temporality {
            case .delta:
                let snapshot = state
                state = emptyState
                state.startTimeNanoseconds = instant.nanosecondsSinceEpoch
                return snapshot
            case .cumulative:
                return state
            }
        }
        var bucketCounts = [UInt64]()
        var explicitBounds = [Double]()
        explicitBounds.reserveCapacity(state.buckets.count)
        bucketCounts.reserveCapacity(state.buckets.count + 1)
        for bucket in state.buckets {
            bucketCounts.append(UInt64(bucket.count))
            explicitBounds.append(bucket.bound.bucketRepresentation)
        }
        bucketCounts.append(UInt64(state.countAboveUpperBound))
        return OTelMetricPoint(
            name: name,
            description: description ?? "",
            unit: unit ?? "",
            data: .histogram(OTelHistogram(
                aggregationTemporality: temporality,
                points: [.init(
                    attributes: attributes.map { OTelAttribute(key: $0.key, value: $0.value) },
                    startTimeNanosecondsSinceEpoch: state.startTimeNanoseconds,
                    timeNanosecondsSinceEpoch: instant.nanosecondsSinceEpoch,
                    count: UInt64(state.count),
                    sum: state.sum.bucketRepresentation,
                    min: state.min?.bucketRepresentation,
                    max: state.max?.bucketRepresentation,
                    bucketCounts: bucketCounts,
                    explicitBounds: explicitBounds,
                )],
            )),
        )
    }
}

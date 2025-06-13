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
    ///
    /// Since our simplifed Swift Metrics backend datamodel only stores the current bucket counts, the only sensible
    /// mapping to an OTel data point we can provide uses cumulative aggregation temporality.
    func measure() -> OTelMetricPoint {
        measure(instant: DefaultTracerClock.now)
    }

    /// Return the current state as an OTel metric data point.
    ///
    /// Since our simplifed Swift Metrics backend datamodel only stores the current bucket counts, the only sensible
    /// mapping to an OTel data point we can provide uses cumulative aggregation temporality.
    func measure(instant: some TracerInstant) -> OTelMetricPoint {
        let state = box.withLockedValue { $0 }
        return OTelMetricPoint(
            name: name,
            description: description ?? "",
            unit: unit ?? "",
            data: .histogram(OTelHistogram(
                aggregationTemporality: .cumulative,
                points: [.init(
                    attributes: attributes.map { OTelAttribute(key: $0.key, value: $0.value) },
                    timeNanosecondsSinceEpoch: instant.nanosecondsSinceEpoch,
                    count: UInt64(state.count),
                    sum: state.sum.bucketRepresentation,
                    min: nil,
                    max: nil,
                    buckets: state.buckets.map {
                        .init(
                            upperBound: $0.bound.bucketRepresentation,
                            count: UInt64($0.count)
                        )
                    } + [
                        .init(
                            upperBound: .infinity,
                            count: UInt64(state.countAboveUpperBound)
                        ),
                    ]
                )]
            ))
        )
    }
}

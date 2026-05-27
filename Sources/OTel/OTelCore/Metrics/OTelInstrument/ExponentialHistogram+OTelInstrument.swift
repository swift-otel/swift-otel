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

import Tracing

extension ExponentialHistogram: OTelMetricInstrument {
    func measure() -> OTelMetricPoint {
        measure(instant: DefaultTracerClock.now)
    }

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

        let count = state.positive.totalCount + state.negative.totalCount + state.zeroCount
        let hasRecordedValues = count > 0

        return OTelMetricPoint(
            name: name,
            description: description ?? "",
            unit: unit ?? "",
            data: .exponentialHistogram(OTelExponentialHistogram(
                aggregationTemporality: temporality,
                points: [.init(
                    attributes: attributes.map { OTelAttribute(key: $0.key, value: $0.value) },
                    startTimeNanosecondsSinceEpoch: state.startTimeNanoseconds,
                    timeNanosecondsSinceEpoch: instant.nanosecondsSinceEpoch,
                    count: count,
                    sum: hasRecordedValues ? state.sum : nil,
                    min: hasRecordedValues ? state.min : nil,
                    max: hasRecordedValues ? state.max : nil,
                    scale: state.scale,
                    zeroCount: state.zeroCount,
                    positive: .init(
                        offset: state.positive.startBin,
                        bucketCounts: state.positive.counts
                    ),
                    negative: .init(
                        offset: state.negative.startBin,
                        bucketCounts: state.negative.counts
                    ),
                )],
            )),
        )
    }
}

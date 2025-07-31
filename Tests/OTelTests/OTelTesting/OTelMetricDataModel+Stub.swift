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

@testable import OTel
import Tracing

extension OTelResource {
    static func stub(
        attributes: SpanAttributes = [:]
    ) -> Self {
        .init(attributes: attributes)
    }
}

extension OTelResourceMetrics {
    static func stub(
        resource: OTelResource? = nil,
        scopeMetrics: [OTelScopeMetrics] = []
    ) -> Self {
        .init(
            resource: resource,
            scopeMetrics: scopeMetrics
        )
    }
}

extension OTelScopeMetrics {
    static func stub(
        scope: OTelInstrumentationScope? = nil,
        metrics: [OTelMetricPoint] = []
    ) -> Self {
        .init(
            scope: scope,
            metrics: metrics
        )
    }
}

extension OTelInstrumentationScope {
    static func stub(
        name: String? = nil,
        version: String? = nil,
        attributes: [OTelAttribute] = [],
        droppedAttributeCount: Int32 = 0
    ) -> Self {
        .init(
            name: name,
            version: version,
            attributes: attributes,
            droppedAttributeCount: droppedAttributeCount
        )
    }
}

extension OTelMetricPoint {
    static func stub(
        name: String = "test",
        description: String = "",
        unit: String = "",
        data: OTelMetricData = .sum(.stub())
    ) -> Self {
        .init(
            name: name,
            description: description,
            unit: unit,
            data: data
        )
    }
}

extension OTelSum {
    static func stub(
        points: [OTelNumberDataPoint] = [],
        aggregationTemporality: OTelAggregationTemporality = .cumulative,
        monotonic: Bool = true
    ) -> Self {
        .init(
            points: points,
            aggregationTemporality: aggregationTemporality,
            monotonic: monotonic
        )
    }
}

extension OTelGauge {
    static func stub(
        points: [OTelNumberDataPoint] = []
    ) -> Self {
        .init(points: points)
    }
}

extension OTelHistogram {
    static func stub(
        aggregationTemporality: OTelAggregationTemporality = .cumulative,
        points: [OTelHistogramDataPoint] = []
    ) -> Self {
        .init(
            aggregationTemporality: aggregationTemporality,
            points: points
        )
    }
}

extension OTelAttribute {
    static func stub(
        key: String = "key",
        value: String = "value"
    ) -> Self {
        .init(
            key: key,
            value: value
        )
    }
}

extension OTelNumberDataPoint {
    static func stub(
        attributes: [OTelAttribute] = [],
        startTimeNanosecondsSinceEpoch: UInt64? = nil,
        timeNanosecondsSinceEpoch: UInt64 = 0,
        value: Value = .int64(0)
    ) -> Self {
        .init(
            attributes: attributes,
            startTimeNanosecondsSinceEpoch: startTimeNanosecondsSinceEpoch,
            timeNanosecondsSinceEpoch: timeNanosecondsSinceEpoch,
            value: value
        )
    }
}

extension OTelHistogramDataPoint {
    static func stub(
        attributes: [OTelAttribute] = [],
        startTimeNanosecondsSinceEpoch: UInt64? = nil,
        timeNanosecondsSinceEpoch: UInt64 = 0,
        count: UInt64 = 0,
        sum: Double? = nil,
        min: Double? = nil,
        max: Double? = nil,
        buckets: [Bucket] = []
    ) -> Self {
        .init(
            attributes: attributes,
            startTimeNanosecondsSinceEpoch: startTimeNanosecondsSinceEpoch,
            timeNanosecondsSinceEpoch: timeNanosecondsSinceEpoch,
            count: count,
            sum: sum,
            min: min,
            max: max,
            buckets: buckets
        )
    }
}

extension OTelHistogramDataPoint.Bucket {
    static func stub(
        upperBound: Double = 0,
        count: UInt64 = 0
    ) -> Self {
        .init(
            upperBound: upperBound,
            count: count
        )
    }
}

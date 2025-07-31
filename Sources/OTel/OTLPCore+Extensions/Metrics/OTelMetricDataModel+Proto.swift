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

import OTLPCore

extension Opentelemetry_Proto_Metrics_V1_ResourceMetrics {
    package init(_ resourceMetrics: OTelResourceMetrics) {
        self.init()
        if let resource = resourceMetrics.resource {
            self.resource = .init(resource)
        }
        scopeMetrics = resourceMetrics.scopeMetrics.map(Opentelemetry_Proto_Metrics_V1_ScopeMetrics.init)
    }
}

extension Opentelemetry_Proto_Resource_V1_Resource {
    package init(_ resource: OTelResource) {
        self.init()
        attributes = .init(resource.attributes)
    }
}

extension Opentelemetry_Proto_Metrics_V1_ScopeMetrics {
    package init(_ scopeMetrics: OTelScopeMetrics) {
        self.init()
        if let scope = scopeMetrics.scope {
            self.scope = .init(scope)
        }
        metrics = scopeMetrics.metrics.map(Opentelemetry_Proto_Metrics_V1_Metric.init)
    }
}

extension Opentelemetry_Proto_Common_V1_InstrumentationScope {
    package init(_ instrumentationScope: OTelInstrumentationScope) {
        self.init()
        if let name = instrumentationScope.name {
            self.name = name
        }
        if let version = instrumentationScope.version {
            self.version = version
        }
        attributes = .init(instrumentationScope.attributes)
        droppedAttributesCount = UInt32(instrumentationScope.droppedAttributeCount)
    }
}

extension Opentelemetry_Proto_Metrics_V1_Metric {
    package init(_ metric: OTelMetricPoint) {
        self.init()
        name = metric.name
        description_p = metric.description
        unit = metric.unit
        switch metric.data.data {
        case .gauge(let gauge):
            self.gauge = .init(gauge)
        case .sum(let sum):
            self.sum = .init(sum)
        case .histogram(let histogram):
            self.histogram = .init(histogram)
        }
    }
}

extension Opentelemetry_Proto_Metrics_V1_Gauge {
    package init(_ gauge: OTelGauge) {
        self.init()
        dataPoints = .init(gauge.points)
    }
}

extension Opentelemetry_Proto_Metrics_V1_Sum {
    package init(_ sum: OTelSum) {
        self.init()
        aggregationTemporality = .init(sum.aggregationTemporality)
        isMonotonic = sum.monotonic
        dataPoints = .init(sum.points)
    }
}

extension Opentelemetry_Proto_Metrics_V1_AggregationTemporality {
    package init(_ aggregationTemporality: OTelAggregationTemporality) {
        switch aggregationTemporality.temporality {
        case .cumulative:
            self = .cumulative
        case .delta:
            self = .delta
        }
    }
}

extension [Opentelemetry_Proto_Metrics_V1_NumberDataPoint] {
    package init(_ points: [OTelNumberDataPoint]) {
        self = points.map(Element.init)
    }
}

extension Opentelemetry_Proto_Metrics_V1_NumberDataPoint {
    package init(_ point: OTelNumberDataPoint) {
        self.init()
        attributes = .init(point.attributes)
        if let startTime = point.startTimeNanosecondsSinceEpoch {
            startTimeUnixNano = startTime
        }
        timeUnixNano = point.timeNanosecondsSinceEpoch
        switch point.value.value {
        case .double(let value):
            self.value = .asDouble(value)
        case .int64(let value):
            self.value = .asInt(value)
        }
    }
}

extension [Opentelemetry_Proto_Common_V1_KeyValue] {
    package init(_ attributes: [OTelAttribute]) {
        self = attributes.map(Element.init)
    }
}

extension Opentelemetry_Proto_Common_V1_KeyValue {
    package init(_ attribute: OTelAttribute) {
        self.init()
        key = attribute.key
        value = Opentelemetry_Proto_Common_V1_AnyValue(attribute.value)
    }
}

extension Opentelemetry_Proto_Common_V1_AnyValue {
    package init(_ string: String) {
        self.init()
        value = .stringValue(string)
    }
}

extension Opentelemetry_Proto_Metrics_V1_Histogram {
    package init(_ histogram: OTelHistogram) {
        self.init()
        aggregationTemporality = .init(histogram.aggregationTemporality)
        dataPoints = .init(histogram.points)
    }
}

extension [Opentelemetry_Proto_Metrics_V1_HistogramDataPoint] {
    package init(_ points: [OTelHistogramDataPoint]) {
        self.init()
        self = points.map(Element.init)
    }
}

extension Opentelemetry_Proto_Metrics_V1_HistogramDataPoint {
    package init(_ point: OTelHistogramDataPoint) {
        self.init()
        attributes = .init(point.attributes)
        if let startTime = point.startTimeNanosecondsSinceEpoch {
            startTimeUnixNano = startTime
        }
        timeUnixNano = point.timeNanosecondsSinceEpoch
        count = point.count
        if let sum = point.sum {
            self.sum = sum
        }
        if let min = point.min {
            self.min = min
        }
        if let max = point.max {
            self.max = max
        }
        for bucket in point.buckets {
            bucketCounts.append(bucket.count)
            explicitBounds.append(bucket.upperBound)
        }
    }
}

extension [Opentelemetry_Proto_Metrics_V1_Metric] {
    package init(_ points: [OTelMetricPoint]) {
        self = points.map(Element.init)
    }
}

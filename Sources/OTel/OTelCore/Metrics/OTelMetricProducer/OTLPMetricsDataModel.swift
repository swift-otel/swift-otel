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

/// The OTel specification describes the distinction between the _event model_, the _timeseries model_, and the
/// _metric stream model_.
///
/// The relevant summary from the specification is as follows:
///
/// > The OTLP Metrics protocol is designed as a standard for transporting metric data. To describe the intended use of
/// > this data and the associated semantic meaning, OpenTelemetry metric data stream types will be linked into a
/// > framework containing a higher-level model, about Metrics APIs and discrete input values, and a lower-level model,
/// > defining the Timeseries and discrete output values.
/// > ...
/// > OpenTelemetry fragments metrics into three interacting models:
/// >
/// > - An Event model, representing how instrumentation reports metric data.
/// > - A Timeseries model, representing how backends store metric data.
/// > - A Metric Stream model, defining the OpenTeLemetry Protocol (OTLP) representing how metric data streams are
/// >   manipulated and transmitted between the Event model and the Timeseries storage. This is the model specified in
/// >   this document.
/// >
/// > — [](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.29.0/specification/metrics/data-model.md#opentelemetry-protocol-data-model)
///
/// The types in this file represent the subset of the OTLP datamodel that we use, which map over the protobuf types.

struct OTelResourceMetrics: Equatable, Sendable {
    var resource: OTelResource?
    var scopeMetrics: [OTelScopeMetrics]
}

struct OTelScopeMetrics: Equatable, Sendable {
    var scope: OTelInstrumentationScope?
    var metrics: [OTelMetricPoint]
}

struct OTelInstrumentationScope: Equatable, Sendable {
    var name: String?
    var version: String?
    var attributes: [OTelAttribute]
    var droppedAttributeCount: Int32
}

struct OTelMetricPoint: Equatable, Sendable {
    var name: String
    var description: String
    var unit: String
    struct OTelMetricData: Equatable, Sendable {
        enum Data: Equatable, Sendable {
            case gauge(OTelGauge)
            case sum(OTelSum)
            case histogram(OTelHistogram)
        }

        var data: Data

        static func gauge(_ data: OTelGauge) -> Self { self.init(data: .gauge(data)) }
        static func sum(_ data: OTelSum) -> Self { self.init(data: .sum(data)) }
        static func histogram(_ data: OTelHistogram) -> Self { self.init(data: .histogram(data)) }
    }

    var data: OTelMetricData
}

struct OTelSum: Equatable, Sendable {
    var points: [OTelNumberDataPoint]
    var aggregationTemporality: OTelAggregationTemporality
    var monotonic: Bool
}

struct OTelGauge: Equatable, Sendable {
    var points: [OTelNumberDataPoint]
}

struct OTelHistogram: Equatable, Sendable {
    var aggregationTemporality: OTelAggregationTemporality
    var points: [OTelHistogramDataPoint]
}

struct OTelAttribute: Hashable, Equatable, Sendable {
    var key: String
    var value: String
}

struct OTelAggregationTemporality: Equatable, Sendable {
    enum Temporality: Equatable, Sendable {
        case delta
        case cumulative
    }

    var temporality: Temporality

    static let delta: Self = .init(temporality: .delta)
    static let cumulative: Self = .init(temporality: .cumulative)
}

struct OTelNumberDataPoint: Equatable, Sendable {
    var attributes: [OTelAttribute]
    var startTimeNanosecondsSinceEpoch: UInt64?
    var timeNanosecondsSinceEpoch: UInt64
    struct Value: Equatable, Sendable {
        enum Value: Equatable, Sendable {
            case int64(Int64)
            case double(Double)
        }

        var value: Value

        static func int64(_ value: Int64) -> Self { self.init(value: .int64(value)) }
        static func double(_ value: Double) -> Self { self.init(value: .double(value)) }
    }

    var value: Value
}

struct OTelHistogramDataPoint: Equatable, Sendable {
    struct Bucket: Equatable, Sendable {
        var upperBound: Double
        var count: UInt64
    }

    var attributes: [OTelAttribute]
    var startTimeNanosecondsSinceEpoch: UInt64?
    var timeNanosecondsSinceEpoch: UInt64
    var count: UInt64
    var sum: Double?
    var min: Double?
    var max: Double?
    var buckets: [Bucket]
}

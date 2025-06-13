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

public struct OTelResourceMetrics: Equatable, Sendable {
    public var resource: OTelResource?
    public var scopeMetrics: [OTelScopeMetrics]
}

public struct OTelScopeMetrics: Equatable, Sendable {
    public var scope: OTelInstrumentationScope?
    public var metrics: [OTelMetricPoint]
}

public struct OTelInstrumentationScope: Equatable, Sendable {
    public var name: String?
    public var version: String?
    public var attributes: [OTelAttribute]
    public var droppedAttributeCount: Int32
}

public struct OTelMetricPoint: Equatable, Sendable {
    public var name: String
    public var description: String
    public var unit: String
    public struct OTelMetricData: Equatable, Sendable {
        package enum Data: Equatable, Sendable {
            case gauge(OTelGauge)
            case sum(OTelSum)
            case histogram(OTelHistogram)
        }

        package var data: Data

        public static func gauge(_ data: OTelGauge) -> Self { self.init(data: .gauge(data)) }
        public static func sum(_ data: OTelSum) -> Self { self.init(data: .sum(data)) }
        public static func histogram(_ data: OTelHistogram) -> Self { self.init(data: .histogram(data)) }
    }

    public var data: OTelMetricData
}

public struct OTelSum: Equatable, Sendable {
    public var points: [OTelNumberDataPoint]
    public var aggregationTemporality: OTelAggregationTemporality
    public var monotonic: Bool
}

public struct OTelGauge: Equatable, Sendable {
    public var points: [OTelNumberDataPoint]
}

public struct OTelHistogram: Equatable, Sendable {
    public var aggregationTemporality: OTelAggregationTemporality
    public var points: [OTelHistogramDataPoint]
}

public struct OTelAttribute: Hashable, Equatable, Sendable {
    public var key: String
    public var value: String
}

public struct OTelAggregationTemporality: Equatable, Sendable {
    package enum Temporality: Equatable, Sendable {
        case delta
        case cumulative
    }

    package var temporality: Temporality

    public static let delta: Self = .init(temporality: .delta)
    public static let cumulative: Self = .init(temporality: .cumulative)
}

public struct OTelNumberDataPoint: Equatable, Sendable {
    public var attributes: [OTelAttribute]
    public var startTimeNanosecondsSinceEpoch: UInt64?
    public var timeNanosecondsSinceEpoch: UInt64
    public struct Value: Equatable, Sendable {
        package enum Value: Equatable, Sendable {
            case int64(Int64)
            case double(Double)
        }

        package var value: Value

        public static func int64(_ value: Int64) -> Self { self.init(value: .int64(value)) }
        public static func double(_ value: Double) -> Self { self.init(value: .double(value)) }
    }

    public var value: Value
}

public struct OTelHistogramDataPoint: Equatable, Sendable {
    public struct Bucket: Equatable, Sendable {
        public var upperBound: Double
        public var count: UInt64
    }

    public var attributes: [OTelAttribute]
    public var startTimeNanosecondsSinceEpoch: UInt64?
    public var timeNanosecondsSinceEpoch: UInt64
    public var count: UInt64
    public var sum: Double?
    public var min: Double?
    public var max: Double?
    public var buckets: [Bucket]
}

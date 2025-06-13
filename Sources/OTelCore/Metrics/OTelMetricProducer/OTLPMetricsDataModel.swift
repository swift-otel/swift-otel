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

package struct OTelResourceMetrics: Equatable, Sendable {
    package var resource: OTelResource?
    package var scopeMetrics: [OTelScopeMetrics]
}

package struct OTelScopeMetrics: Equatable, Sendable {
    package var scope: OTelInstrumentationScope?
    package var metrics: [OTelMetricPoint]
}

package struct OTelInstrumentationScope: Equatable, Sendable {
    package var name: String?
    package var version: String?
    package var attributes: [OTelAttribute]
    package var droppedAttributeCount: Int32
}

package struct OTelMetricPoint: Equatable, Sendable {
    package var name: String
    package var description: String
    package var unit: String
    package struct OTelMetricData: Equatable, Sendable {
        package enum Data: Equatable, Sendable {
            case gauge(OTelGauge)
            case sum(OTelSum)
            case histogram(OTelHistogram)
        }

        package var data: Data

        package static func gauge(_ data: OTelGauge) -> Self { self.init(data: .gauge(data)) }
        package static func sum(_ data: OTelSum) -> Self { self.init(data: .sum(data)) }
        package static func histogram(_ data: OTelHistogram) -> Self { self.init(data: .histogram(data)) }
    }

    package var data: OTelMetricData
}

package struct OTelSum: Equatable, Sendable {
    package var points: [OTelNumberDataPoint]
    package var aggregationTemporality: OTelAggregationTemporality
    package var monotonic: Bool
}

package struct OTelGauge: Equatable, Sendable {
    package var points: [OTelNumberDataPoint]
}

package struct OTelHistogram: Equatable, Sendable {
    package var aggregationTemporality: OTelAggregationTemporality
    package var points: [OTelHistogramDataPoint]
}

package struct OTelAttribute: Hashable, Equatable, Sendable {
    package var key: String
    package var value: String
}

package struct OTelAggregationTemporality: Equatable, Sendable {
    package enum Temporality: Equatable, Sendable {
        case delta
        case cumulative
    }

    package var temporality: Temporality

    package static let delta: Self = .init(temporality: .delta)
    package static let cumulative: Self = .init(temporality: .cumulative)
}

package struct OTelNumberDataPoint: Equatable, Sendable {
    package var attributes: [OTelAttribute]
    package var startTimeNanosecondsSinceEpoch: UInt64?
    package var timeNanosecondsSinceEpoch: UInt64
    package struct Value: Equatable, Sendable {
        package enum Value: Equatable, Sendable {
            case int64(Int64)
            case double(Double)
        }

        package var value: Value

        package static func int64(_ value: Int64) -> Self { self.init(value: .int64(value)) }
        package static func double(_ value: Double) -> Self { self.init(value: .double(value)) }
    }

    package var value: Value
}

package struct OTelHistogramDataPoint: Equatable, Sendable {
    package struct Bucket: Equatable, Sendable {
        package var upperBound: Double
        package var count: UInt64
    }

    package var attributes: [OTelAttribute]
    package var startTimeNanosecondsSinceEpoch: UInt64?
    package var timeNanosecondsSinceEpoch: UInt64
    package var count: UInt64
    package var sum: Double?
    package var min: Double?
    package var max: Double?
    package var buckets: [Bucket]
}

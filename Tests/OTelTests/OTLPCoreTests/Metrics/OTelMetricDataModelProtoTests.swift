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
import OTLPCore
import XCTest

final class OTelMetricDataModelProtoTests: XCTestCase {
    func test_initProto_resourceUnset_protoHasNoResource() {
        let resourceMetrics = OTelResourceMetrics.stub(resource: nil)
        let proto = Opentelemetry_Proto_Metrics_V1_ResourceMetrics(resourceMetrics)
        XCTAssertFalse(proto.hasResource)
    }

    func test_initProto_resourceSet_protoHasResource() {
        let resourceMetrics = OTelResourceMetrics.stub(resource: .stub())
        let proto = Opentelemetry_Proto_Metrics_V1_ResourceMetrics(resourceMetrics)
        XCTAssertTrue(proto.hasResource)
    }

    func test_initProto_resourceMetrics_protoHasMetrics() {
        let resourceMetrics = OTelResourceMetrics.stub(scopeMetrics: [.stub()])
        let proto = Opentelemetry_Proto_Metrics_V1_ResourceMetrics(resourceMetrics)
        XCTAssertEqual(proto.scopeMetrics.count, 1)
    }

    func test_initProto_resourceHasAttribute_protoHasAttribute() {
        let resource = OTelResource.stub(attributes: ["k": "v"])
        let proto = Opentelemetry_Proto_Resource_V1_Resource(resource)
        XCTAssert(proto.attributes.contains { $0.key == "k" && $0.value.stringValue == "v" })
    }

    func test_initProto_scopeUnset_protoHasNoScope() {
        let scope = OTelScopeMetrics.stub(scope: nil)
        let proto = Opentelemetry_Proto_Metrics_V1_ScopeMetrics(scope)
        XCTAssertFalse(proto.hasScope)
    }

    func test_initProto_scopeSet_protoHasScope() {
        let scope = OTelScopeMetrics.stub(scope: .stub())
        let proto = Opentelemetry_Proto_Metrics_V1_ScopeMetrics(scope)
        XCTAssertTrue(proto.hasScope)
    }

    func test_initProto_scopeMetrics_protoHasMetrics() {
        let scope = OTelScopeMetrics.stub(metrics: [.stub(), .stub()])
        let proto = Opentelemetry_Proto_Metrics_V1_ScopeMetrics(scope)
        XCTAssertEqual(proto.metrics.count, 2)
    }

    func test_initProto_scopeFields_protoHasFields() {
        let scope = OTelInstrumentationScope.stub(
            name: "n",
            version: "v",
            attributes: [.stub()],
            droppedAttributeCount: 42
        )
        let proto = Opentelemetry_Proto_Common_V1_InstrumentationScope(scope)
        XCTAssertEqual(proto.name, "n")
        XCTAssertEqual(proto.version, "v")
        XCTAssertEqual(proto.attributes.count, 1)
        XCTAssertEqual(proto.droppedAttributesCount, 42)
    }

    func test_initProto_metricPointFields_protoHasFields() {
        let point = OTelMetricPoint.stub(name: "n", description: "d", unit: "u")
        let proto = Opentelemetry_Proto_Metrics_V1_Metric(point)
        XCTAssertEqual(proto.name, "n")
        XCTAssertEqual(proto.description_p, "d")
        XCTAssertEqual(proto.unit, "u")
    }

    func test_initProto_metricPointSum_protoHasSum() {
        let point = OTelMetricPoint.stub(data: .sum(.stub()))
        let proto = Opentelemetry_Proto_Metrics_V1_Metric(point)
        guard case .sum = proto.data else {
            XCTFail("unexpected data point kind")
            return
        }
    }

    func test_initProto_metricPointGauge_protoHasGauge() {
        let point = OTelMetricPoint.stub(data: .gauge(.stub()))
        let proto = Opentelemetry_Proto_Metrics_V1_Metric(point)
        guard case .gauge = proto.data else {
            XCTFail("unexpected data point kind")
            return
        }
    }

    func test_initProto_metricPointHistogram_protoHasHistogram() {
        let point = OTelMetricPoint.stub(data: .histogram(.stub(points: [.stub(), .stub()])))
        let proto = Opentelemetry_Proto_Metrics_V1_Metric(point)
        guard case .histogram(let histogram) = proto.data else {
            XCTFail("unexpected data point kind")
            return
        }
        XCTAssertEqual(histogram.dataPoints.count, 2)
    }

    func test_initProto_metricPointHistogramPoints_protoHasPoints() {
        let point = OTelMetricPoint.stub(data: .histogram(.stub(points: [.stub(), .stub()])))
        let proto = Opentelemetry_Proto_Metrics_V1_Metric(point)
        guard case .histogram = proto.data else {
            XCTFail("unexpected data point kind")
            return
        }
    }

    func test_initProto_sumDelta_protoHasFields() {
        let sum = OTelSum.stub(aggregationTemporality: .delta, monotonic: false)
        let proto = Opentelemetry_Proto_Metrics_V1_Sum(sum)
        XCTAssertEqual(proto.aggregationTemporality, .delta)
        XCTAssertEqual(proto.isMonotonic, false)
    }

    func test_initProto_sumCumulative_protoHasFields() {
        let sum = OTelSum.stub(aggregationTemporality: .cumulative, monotonic: true)
        let proto = Opentelemetry_Proto_Metrics_V1_Sum(sum)
        XCTAssertEqual(proto.aggregationTemporality, .cumulative)
        XCTAssertEqual(proto.isMonotonic, true)
    }

    func test_initProto_sumPoints_protoHasPoints() {
        let sum = OTelSum.stub(points: [.stub(), .stub()])
        let proto = Opentelemetry_Proto_Metrics_V1_Sum(sum)
        XCTAssertEqual(proto.dataPoints.count, 2)
    }

    func test_initProto_pointFields_protoHasFields() {
        let point = OTelNumberDataPoint.stub(
            attributes: [.stub()],
            startTimeNanosecondsSinceEpoch: 42,
            timeNanosecondsSinceEpoch: 84
        )
        let proto = Opentelemetry_Proto_Metrics_V1_NumberDataPoint(point)
        XCTAssertEqual(proto.attributes.count, 1)
        XCTAssertEqual(proto.startTimeUnixNano, 42)
        XCTAssertEqual(proto.timeUnixNano, 84)
    }

    func test_initProto_pointInt_protoHasInt() {
        let point = OTelNumberDataPoint.stub(value: .int64(42))
        let proto = Opentelemetry_Proto_Metrics_V1_NumberDataPoint(point)
        guard case .asInt(let value) = proto.value else {
            XCTFail("unexpected value kind")
            return
        }
        XCTAssertEqual(value, 42)
    }

    func test_initProto_pointDouble_protoHasDouble() {
        let point = OTelNumberDataPoint.stub(value: .double(42))
        let proto = Opentelemetry_Proto_Metrics_V1_NumberDataPoint(point)
        guard case .asDouble(let value) = proto.value else {
            XCTFail("unexpected value kind")
            return
        }
        XCTAssertEqual(value, 42)
    }

    func test_initProto_histogramPointFields_protoHasFields() {
        let point = OTelHistogramDataPoint.stub(
            attributes: [.stub()],
            startTimeNanosecondsSinceEpoch: 42,
            timeNanosecondsSinceEpoch: 84,
            count: 12,
            sum: 13,
            min: 14,
            max: 15,
            buckets: [.stub(), .stub()]
        )
        let proto = Opentelemetry_Proto_Metrics_V1_HistogramDataPoint(point)
        XCTAssertEqual(proto.attributes.count, 1)
        XCTAssertEqual(proto.startTimeUnixNano, 42)
        XCTAssertEqual(proto.timeUnixNano, 84)
        XCTAssertEqual(proto.count, 12)
        XCTAssertEqual(proto.sum, 13)
        XCTAssertEqual(proto.min, 14)
        XCTAssertEqual(proto.max, 15)
        XCTAssertEqual(proto.bucketCounts.count, 2)
    }
}

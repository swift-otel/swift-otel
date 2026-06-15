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

extension OTelMetricRegistry: OTelMetricProducer {
    func produce() -> [OTelMetricPoint] {
        let metrics = storage.withLockedValue { $0 }
        var buffer: [OTelMetricPoint] = []
        buffer.reserveCapacity(1024) // TODO: Make this configurable? Also, does this overlap with OTel "cardinality"?
        appendGrouped(metrics.counters, to: &buffer)
        appendGrouped(metrics.floatingPointCounters, to: &buffer)
        appendGrouped(metrics.gauges, to: &buffer)
        appendGrouped(metrics.durationHistograms, to: &buffer)
        appendGrouped(metrics.valueHistograms, to: &buffer)
        return buffer
    }

    /// Measure every instrument sharing an identifier (name, unit, description, kind) and emit them
    /// as a single metric point carrying one data point per attribute set.
    ///
    /// Per the OTLP data model, a `Metric` object contains the individual streams for a given name,
    /// each identified by its set of attributes. Emitting a separate `Metric` per stream produces
    /// multiple `Metric` identities for one name, which the specification calls a "semantic error".
    /// See https://opentelemetry.io/docs/specs/otel/metrics/data-model/#opentelemetry-protocol-data-model-producer-recommendations
    private func appendGrouped(
        _ instrumentsByIdentifier: [InstrumentIdentifier: [Set<Attribute>: some OTelMetricInstrument]],
        to buffer: inout [OTelMetricPoint]
    ) {
        for instruments in instrumentsByIdentifier.values {
            var iterator = instruments.values.makeIterator()
            // The first measurement seeds the metric point's identifying fields and data kind; the
            // rest only contribute their data points, which all match that kind by construction.
            guard var point = iterator.next()?.measure() else { continue }
            while let next = iterator.next() {
                point.data.data.appendDataPoints(from: next.measure().data.data)
            }
            buffer.append(point)
        }
    }
}

extension OTelMetricPoint.OTelMetricData.Data {
    /// Appends the data points of `other` to this metric data.
    ///
    /// - Precondition: `other` must be the same kind (sum, gauge, or histogram). Instruments that
    ///   share an identifier always produce the same kind, so a mismatch is a programming error
    ///   rather than something that can be silently dropped.
    fileprivate mutating func appendDataPoints(from other: Self) {
        switch self {
        case .sum(var data):
            guard case .sum(let other) = other else { preconditionFailure(Self.kindMismatch) }
            data.points.append(contentsOf: other.points)
            self = .sum(data)
        case .gauge(var data):
            guard case .gauge(let other) = other else { preconditionFailure(Self.kindMismatch) }
            data.points.append(contentsOf: other.points)
            self = .gauge(data)
        case .histogram(var data):
            guard case .histogram(let other) = other else { preconditionFailure(Self.kindMismatch) }
            data.points.append(contentsOf: other.points)
            self = .histogram(data)
        }
    }

    private static let kindMismatch =
        "Instruments sharing an identifier must produce the same metric kind."
}

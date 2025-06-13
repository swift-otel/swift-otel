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
//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftPrometheus open source project
//
// Copyright (c) 2018-2023 SwiftPrometheus project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftPrometheus project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import CoreMetrics

/// A Swift Metrics `MetricsFactory` implementation backed by ``OTelMetricRegistry``.
public struct OTLPMetricsFactory: Sendable {
    private static let _defaultRegistry = OTelMetricRegistry()

    /// The shared, default registry.
    public static var defaultRegistry: OTelMetricRegistry {
        _defaultRegistry
    }

    /// The underlying registry that provides the handler for the Swift Metrics API.
    let registry: OTelMetricRegistry

    /// Configuration options for the metrics factory.
    let configuration: Configuration

    /// Create a new ``OTLPMetricsFactory``.
    /// - Parameters:
    ///   - registry: The registry to store metrics.
    ///   - configuration: Configuration options for the factory.
    ///
    /// - Seealso: ``OTLPMetricsFactory/Configuration``.
    public init(registry: OTelMetricRegistry = defaultRegistry, configuration: Configuration = .default) {
        self.registry = registry
        self.configuration = configuration
    }
}

extension OTLPMetricsFactory {
    /// Configuration options for the metrics factory.
    ///
    /// - Seealso: See the static property ``default`` for details on the default configuration values.
    public struct Configuration: Sendable {
        /// The default bucket upper bounds for duration histograms created for a Swift Metrics `Timer`.
        public var defaultDurationHistogramBuckets: [Duration]

        /// The bucket upper bounds for duration histograms created for a Swift Metrics `Timer` with a specific label.
        public var durationHistogramBuckets: [String: [Duration]]

        /// The default bucket upper bounds for value histograms created for a Swift Metrics `Recorder`.
        public var defaultValueHistogramBuckets: [Double]

        /// The bucket upper bounds for value histograms created for a Swift Metrics `Recorder` with a specific label.
        public var valueHistogramBuckets: [String: [Double]]

        /// A closure to drop or modify metric registration made using the Swift Metrics API.
        ///
        /// This allows users to interpose registrations made by third party packages.
        ///
        /// The closure will be called for each registration with the `label` and `dimensions` provided to the Swift Metrics
        /// API and should return the label and dimensions to actually use, or `nil` if this metric should be dropped.
        public var registrationPreprocessor: @Sendable (_ label: String, _ dimensions: [(String, String)]) -> (String, [(String, String)])?

        /// The default bucket upper bounds for histograms defined by the [OTel specification].
        ///
        /// The specification outlines the following bounds to be used when no metric-specific bounds are defined:
        ///
        /// `(-∞, 0], (0, 5.0], (5.0, 10.0], (10.0, 25.0], (25.0, 50.0], (50.0, 75.0], (75.0, 100.0], (100.0, 250.0],
        /// (250.0, 500.0], (500.0, 750.0], (750.0, 1000.0], (1000.0, 2500.0], (2500.0, 5000.0], (5000.0, 7500.0],
        /// (7500.0, 10000.0], (10000.0, +∞)`
        //
        /// - Seealso: Use ``defaultValueHistogramBuckets`` and ``defaultDurationHistogramBuckets`` to use different
        /// default bucket bounds for metrics created using the Swift Metrics `Recorder` and `Timer` APIs respectively.
        /// - Seealso: Use ``valueHistogramBuckets`` and ``durationHistogramBuckets`` to override the bucket bounds for
        ///   specific metrics created using the Swift Metrics `Recorder` and `Timer` APIs respectively.
        ///
        ///  [OTel specification]: https://github.com/open-telemetry/opentelemetry-specification/blob/v1.29.0/specification/metrics/sdk.md#explicit-bucket-histogram-aggregation
        public static let defaultOTelHistogramBuckets: [Double] = [
            0,
            5,
            10,
            25,
            50,
            75,
            100,
            250,
            500,
            750,
            1000,
            2500,
            5000,
            7500,
            10000,
        ]

        /// Default configuration options.
        ///
        /// ## Histogram bucket bounds
        ///
        /// By default, the configuration uses the [default histogram bucket bounds defined in the OTel
        /// specification][0]:
        ///
        /// `(-∞, 0], (0, 5.0], (5.0, 10.0], (10.0, 25.0], (25.0, 50.0], (50.0, 75.0], (75.0, 100.0], (100.0, 250.0],
        /// (250.0, 500.0], (500.0, 750.0], (750.0, 1000.0], (1000.0, 2500.0], (2500.0, 5000.0], (5000.0, 7500.0],
        /// (7500.0, 10000.0], (10000.0, +∞)`
        ///
        /// When used for duration histograms, these values are used as millisecond durations.
        ///
        /// Use ``OTLPMetricsFactory/Configuration/defaultValueHistogramBuckets`` and ``OTLPMetricsFactory/Configuration/defaultDurationHistogramBuckets`` to use different
        /// default bucket bounds for metrics created using the Swift Metrics `Recorder` and `Timer` APIs respectively.
        ///
        /// Use ``OTLPMetricsFactory/Configuration/valueHistogramBuckets`` and ``OTLPMetricsFactory/Configuration/durationHistogramBuckets`` to override the bucket bounds for
        ///   _specific_ metrics created using the Swift Metrics `Recorder` and `Timer` APIs respectively.
        ///
        /// ## Metric registration
        ///
        /// The metrics factory will handle all metric registrations using the Swift Metrics API, including those made
        /// by third-party libraries. For this reason it can be useful to customize the registration behavior.
        ///
        /// Use ``OTLPMetricsFactory/Configuration/registrationPreprocessor`` to customize the label and/or dimensions
        /// of metric, or drop the metric entirely. The default preprocessor will pass through all metrics unmodified.
        ///
        /// The OTel specification defines what instrument fields are considered _identifying_ and [how SDKs should
        /// handle duplicate instrument registration][1]. By default a warning is emitted to the logging system. Note
        /// that this warning will not be surfaced if no logging backend has been configured.
        ///
        /// Use ``OTelMetricRegistry/init(onDuplicateRegistration:)`` to customize the action to take when duplicate
        /// registration occurs.
        ///
        /// [0]: https://github.com/open-telemetry/opentelemetry-specification/blob/v1.29.0/specification/metrics/sdk.md#explicit-bucket-histogram-aggregation
        /// [1]: https://github.com/open-telemetry/opentelemetry-specification/blob/v1.29.0/specification/metrics/sdk.md#duplicate-instrument-registration
        public static let `default` = Self(
            defaultDurationHistogramBuckets: defaultOTelHistogramBuckets.map(Duration.milliseconds),
            durationHistogramBuckets: [:],
            defaultValueHistogramBuckets: defaultOTelHistogramBuckets,
            valueHistogramBuckets: [:],
            registrationPreprocessor: { ($0, $1) }
        )
    }
}

extension OTLPMetricsFactory: CoreMetrics.MetricsFactory {
    public func makeCounter(label: String, dimensions: [(String, String)]) -> CoreMetrics.CounterHandler {
        guard let (label, dimensions) = configuration.registrationPreprocessor(label, dimensions) else {
            return NOOPMetricsHandler.instance.makeCounter(label: label, dimensions: dimensions)
        }
        let (unit, description, attributes) = extractIdentifyingFieldsAndAttributes(from: dimensions)
        return registry.makeCounter(name: label, unit: unit, description: description, attributes: attributes)
    }

    public func makeFloatingPointCounter(label: String, dimensions: [(String, String)]) -> CoreMetrics.FloatingPointCounterHandler {
        guard let (label, dimensions) = configuration.registrationPreprocessor(label, dimensions) else {
            return NOOPMetricsHandler.instance.makeFloatingPointCounter(label: label, dimensions: dimensions)
        }
        let (unit, description, attributes) = extractIdentifyingFieldsAndAttributes(from: dimensions)
        return registry.makeFloatingPointCounter(name: label, unit: unit, description: description, attributes: attributes)
    }

    public func makeRecorder(
        label: String,
        dimensions: [(String, String)],
        aggregate: Bool
    ) -> CoreMetrics.RecorderHandler {
        guard let (label, dimensions) = configuration.registrationPreprocessor(label, dimensions) else {
            return NOOPMetricsHandler.instance.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
        }
        let (unit, description, attributes) = extractIdentifyingFieldsAndAttributes(from: dimensions)
        guard aggregate else {
            return registry.makeGauge(name: label, unit: unit, description: description, attributes: attributes)
        }
        let buckets = configuration.valueHistogramBuckets[label] ?? configuration.defaultValueHistogramBuckets
        return registry.makeValueHistogram(name: label, unit: unit, description: description, attributes: attributes, buckets: buckets)
    }

    public func makeMeter(label: String, dimensions: [(String, String)]) -> CoreMetrics.MeterHandler {
        guard let (label, dimensions) = configuration.registrationPreprocessor(label, dimensions) else {
            return NOOPMetricsHandler.instance.makeMeter(label: label, dimensions: dimensions)
        }
        let (unit, description, attributes) = extractIdentifyingFieldsAndAttributes(from: dimensions)
        return registry.makeGauge(name: label, unit: unit, description: description, attributes: attributes)
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> CoreMetrics.TimerHandler {
        guard let (label, dimensions) = configuration.registrationPreprocessor(label, dimensions) else {
            return NOOPMetricsHandler.instance.makeTimer(label: label, dimensions: dimensions)
        }
        let (unit, description, attributes) = extractIdentifyingFieldsAndAttributes(from: dimensions)
        let buckets = configuration.durationHistogramBuckets[label] ?? configuration.defaultDurationHistogramBuckets
        return registry.makeDurationHistogram(name: label, unit: unit, description: description, attributes: attributes, buckets: buckets)
    }

    public func destroyCounter(_ handler: CoreMetrics.CounterHandler) {
        guard let counter = handler as? Counter else {
            return
        }
        registry.unregisterCounter(counter)
    }

    public func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler) {
        guard let counter = handler as? FloatingPointCounter else {
            return
        }
        registry.unregisterFloatingPointCounter(counter)
    }

    public func destroyRecorder(_ handler: CoreMetrics.RecorderHandler) {
        switch handler {
        case let gauge as Gauge:
            registry.unregisterGauge(gauge)
        case let histogram as Histogram<Double>:
            registry.unregisterValueHistogram(histogram)
        default:
            break
        }
    }

    public func destroyMeter(_ handler: CoreMetrics.MeterHandler) {
        guard let gauge = handler as? Gauge else {
            return
        }
        registry.unregisterGauge(gauge)
    }

    public func destroyTimer(_ handler: CoreMetrics.TimerHandler) {
        guard let histogram = handler as? Histogram<Duration> else {
            return
        }
        registry.unregisterDurationHistogram(histogram)
    }
}

// MARK: - Helpers

extension OTLPMetricsFactory {
    /// Returns the values for keys `unit` and `description`, if they are present in the array.
    private func extractIdentifyingFieldsAndAttributes(from dimensions: [(String, String)]) -> (unit: String?, description: String?, Set<Attribute>) {
        var unit: String?
        var description: String?
        var attributes = Set<Attribute>()
        for (key, value) in dimensions {
            switch key {
            case "unit": unit = value
            case "description": description = value
            default: attributes.insert(Attribute(key: key, value: value))
            }
        }
        return (unit, description, attributes)
    }
}

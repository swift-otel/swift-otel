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

import AsyncAlgorithms
import Logging
import ServiceLifecycle

struct OTelPeriodicExportingMetricsReader<Clock: _Concurrency.Clock> where Clock.Duration == Duration {
    private let logger: Logger

    var resource: OTelResource
    var producer: OTelMetricProducer
    var exporter: OTelMetricExporter
    var configuration: OTelPeriodicExportingMetricsReaderConfiguration
    var clock: Clock

    init(
        resource: OTelResource,
        producer: OTelMetricProducer,
        exporter: OTelMetricExporter,
        configuration: OTelPeriodicExportingMetricsReaderConfiguration,
        logger: Logger,
        clock: Clock
    ) {
        self.resource = resource
        self.producer = producer
        self.exporter = exporter
        self.configuration = configuration
        self.logger = logger.withMetadata(component: "OTelPeriodicExportingMetricsReader")
        self.clock = clock
    }

    func tick() async {
        logger.trace("Reading metrics from producer.")
        let metrics = producer.produce()
        let batch = [
            OTelResourceMetrics(
                resource: resource,
                scopeMetrics: [OTelScopeMetrics(
                    scope: .init(name: "swift-otel", version: OTelLibrary.version, attributes: [], droppedAttributeCount: 0),
                    metrics: metrics
                )]
            ),
        ]
        logger.debug("Exporting metrics.", metadata: ["count": "\(metrics.count)"])
        do {
            try await withTimeout(configuration.exportTimeout, clock: clock) {
                try await exporter.export(batch)
            }
        } catch is CancellationError {
            logger.warning("Timed out exporting metrics.", metadata: ["timeout": "\(configuration.exportTimeout)"])
        } catch {
            logger.error("Failed to export metrics.", metadata: ["error": "\(error)"])
        }
    }
}

extension OTelPeriodicExportingMetricsReader: CustomStringConvertible, Service {
    var description: String { "OTelPeriodicExportingMetricsReader" }

    func run() async throws {
        let interval = configuration.exportInterval
        logger.info("Started periodic loop.", metadata: ["interval": "\(interval)"])
        for try await _ in AsyncTimerSequence.repeating(every: interval, clock: clock).cancelOnGracefulShutdown() {
            logger.trace("Timer fired.", metadata: ["interval": "\(interval)"])
            await tick()
        }
        logger.debug("Shutting down.")
        // Unlike traces, force-flush is just a regular tick for metrics; no need for a different function.
        await tick()
        try await exporter.forceFlush()
        await exporter.shutdown()
        logger.debug("Shut down.")
    }
}

extension OTelPeriodicExportingMetricsReader where Clock == ContinuousClock {
    /// Create a new ``OTelPeriodicExportingMetricsReader``.
    ///
    /// - Parameters:
    ///   - resource: The resource associated with the metrics, usually obtained using <doc:resource-detection>.
    ///   - producer: The producer used to periodically read metrics.
    ///   - exporter: The exporter to use to export the metrics.
    ///   - configuration: The configuration options for the periodic exporting reader.
    init(
        resource: OTelResource,
        producer: OTelMetricProducer,
        exporter: OTelMetricExporter,
        configuration: OTelPeriodicExportingMetricsReaderConfiguration,
        logger: Logger
    ) {
        self.init(
            resource: resource,
            producer: producer,
            exporter: exporter,
            configuration: configuration,
            logger: logger,
            clock: .continuous
        )
    }
}

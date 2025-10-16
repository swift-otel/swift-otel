//
//  OTelPeriodicProfileSampler.swift
//  swift-otel
//

import _ProfileRecorderSampleConversion
import AsyncAlgorithms
import Foundation
import Logging
import NIOCore
import NIOFileSystem
import ProfileRecorder
import ServiceLifecycle

struct OTelPeriodicProfileSampler<Clock: _Concurrency.Clock> where Clock.Duration == Duration {
    private let logger: Logger

    var resource: OTelResource
    var exporter: OTelProfileExporter
    var configuration: OTel.Configuration.ProfilesConfiguration
    var clock: Clock

    init(
        resource: OTelResource,
        exporter: OTelProfileExporter,
        configuration: OTel.Configuration.ProfilesConfiguration,
        logger: Logger,
        clock: Clock
    ) {
        self.resource = resource
        self.exporter = exporter
        self.configuration = configuration
        self.logger = logger.withMetadata(component: "OTelPeriodicExportingProfileSampler")
        self.clock = clock
    }

    func tick() async {
        do {
            let symbolizer: any Symbolizer = ProfileRecorderSampler._makeDefaultSymbolizer()
            let result = try await FileSystem.shared.withTemporaryDirectory {
                _,
                    tmpDirPath in
                let symbolisedSamplesPath = tmpDirPath.appending("samples.otlp.pb")

                return try await ProfileRecorderSampler.sharedInstance._withSamples(
                    sampleCount: 1,
                    timeBetweenSamples: .zero,
                    format: .raw,
                    symbolizer: symbolizer,
                    logger: logger
                ) { rawSamplesPath in
                    let renderer = OTLPProfileSampleRenderer()
                    let converter = ProfileRecorderSampleConverter(
                        config: .default,
                        renderer: renderer,
                        symbolizer: symbolizer
                    )
                    try await converter.convert(
                        inputRawProfileRecorderFormatPath: rawSamplesPath,
                        outputPath: symbolisedSamplesPath.string,
                        format: .perfSymbolized,
                        logger: logger
                    )
                    return renderer.resultForSwiftOTel
                }
            }

            let batch = [
                Opentelemetry_Proto_Profiles_V1development_ResourceProfiles.with {
                    $0.resource = .init(resource)
                    $0.scopeProfiles = [.with {
                        $0.scope = .with {
                            $0.name = "swift-otel"
                            $0.version = OTelLibrary.version
                            $0.attributes = []
                            $0.droppedAttributesCount = 0
                        }
                        $0.profiles = result.resourceProfiles.first!.scopeProfiles.first!.profiles
                    }]
                },
            ]
            try await exporter.export(batch, result.dictionary)
        } catch {
            logger.info("samples failed", metadata: ["error": "\(error)"])
        }
    }
}

extension OTelPeriodicProfileSampler: Service {
    func run() async throws {
        let interval = configuration.exportInterval
        logger.debug("Started periodic loop.", metadata: ["interval": "\(interval)"])
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

extension OTelPeriodicProfileSampler where Clock == ContinuousClock {
    init(
        resource: OTelResource,
        exporter: OTelProfileExporter,
        configuration: OTel.Configuration.ProfilesConfiguration,
        logger: Logger
    ) {
        self.resource = resource
        self.exporter = exporter
        self.configuration = configuration
        self.logger = logger.withMetadata(component: "OTelPeriodicProfileSampler")
        clock = .continuous
    }
}

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

import Logging
import Tracing

/// A type facilitating the resource detection process using a configurable set of resource detectors.
public struct OTelResourceDetection<Clock: _Concurrency.Clock>: Sendable where Clock.Duration == Duration {
    /// The resource detectors to be run when calling ``resource(environment:logLevel:)``.
    public var detectors: [any OTelResourceDetector]

    /// A timeout after which resource detection will be cancelled. Defaults to `3` seconds.
    public var timeout: Duration

    private let clock: Clock

    @_spi(Testing)
    public init(detectors: [any OTelResourceDetector], timeout: Duration, clock: Clock) {
        self.detectors = detectors
        self.timeout = timeout
        self.clock = clock
    }

    /// Returns the combined resource from running all configured resource detectors.
    ///
    /// - Parameters:
    ///   - environment: The environment variables, used to look up the `OTEL_SERVICE_NAME` variable.
    ///   - logLevel: The minimum log level used during resource detection. Defaults to `.info`.
    ///
    /// - Returns: The combined resource from running all configured resource detectors.
    public func resource(environment: OTelEnvironment, logLevel: Logger.Level = .info) async -> OTelResource {
        let sdkResource = OTelResource(attributes: [
            "telemetry.sdk.name": "opentelemetry",
            "telemetry.sdk.language": "swift",
            "telemetry.sdk.version": "\(OTelLibrary.version)",
        ])

        let logger = Logger(label: "OTelResourceDetection") { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = logLevel
            return handler
        }

        let resource = await withThrowingTaskGroup(of: OTelResource.self, returning: OTelResource.self) { group in
            group.addTask {
                await detectedResource(sdkResource: sdkResource, logger: logger)
            }

            group.addTask {
                try? await Task.sleep(for: timeout, clock: clock)
                throw CancellationError()
            }

            do {
                let resource = try await group.next()!
                group.cancelAll()
                return resource
            } catch {
                logger.notice("Resource detection timed out.")
                group.cancelAll()
                return sdkResource
            }
        }

        let serviceName = serviceName(environment: environment, resource: resource, logger: logger)
        return resource.merging(OTelResource(attributes: ["service.name": "\(serviceName)"]))
    }

    private func detectedResource(sdkResource: OTelResource, logger: Logger) async -> OTelResource {
        await withTaskGroup(of: (Int, OTelResource).self, returning: OTelResource.self) { group in
            logger.trace("Running resource detectors.", metadata: [
                "detectors": .array(detectors.map { "\($0)" }),
            ])

            for (index, detector) in detectors.enumerated() {
                group.addTask {
                    do {
                        let resource = try await detector.resource(logger: logger)
                        logger.trace("Detected resource.", metadata: ["detector": "\(detector)"])
                        return (index, resource)
                    } catch {
                        logger.error("Failed to detect resource.", metadata: [
                            "detector": "\(detector)",
                            "error_type": "\(type(of: error))",
                            "error_description": "\(error)",
                        ])
                        return (index, OTelResource())
                    }
                }
            }

            return await group
                .reduce(into: [Int: OTelResource]()) { $0[$1.0] = $1.1 }
                .lazy
                .sorted { $0.key < $1.key }
                .reduce(sdkResource) { $0.merging($1.value) }
        }
    }

    private func serviceName(environment: OTelEnvironment, resource: OTelResource, logger: Logger) -> String {
        if let serviceName = environment["OTEL_SERVICE_NAME"] {
            logger.debug(#"Using service name from "OTEL_SERVICE_NAME" environment variable."#, metadata: [
                "service_name": "\(serviceName)",
            ])
            return serviceName
        } else if case .string(let serviceName) = resource.attributes["service.name"]?.toSpanAttribute() {
            logger.debug("Using service name from resource attributes.", metadata: ["service_name": "\(serviceName)"])
            return serviceName
        } else {
            let fallback: String = {
                let executableNameAttribute = resource.attributes["process.executable.name"]?.toSpanAttribute()
                if case .string(let executableName) = executableNameAttribute {
                    return "unknown_service:\(executableName)"
                } else {
                    return "unknown_service"
                }
            }()
            logger.notice("No service name was provided.", metadata: ["fallback_service_name": "\(fallback)"])
            return fallback
        }
    }
}

extension OTelResourceDetection where Clock == ContinuousClock {
    /// Create a resource detection with the provided detectors and timeout.
    ///
    /// - Parameters:
    ///   - detectors: A set of resource detectors to run.
    ///   Duplicate resource attributes will be resolved in the provided order, i.e. later resource detectors will override values from earlier ones.
    ///   - timeout: A timeout after which resource detection will be cancelled. Defaults to `3` seconds.
    public init(detectors: [any OTelResourceDetector], timeout: Duration = .seconds(3)) {
        self.init(detectors: detectors, timeout: timeout, clock: .continuous)
    }
}

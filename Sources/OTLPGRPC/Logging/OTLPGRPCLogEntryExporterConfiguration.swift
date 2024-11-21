//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2024 Moritz Lang and the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOHPACK
import OTel

@_spi(Logging)
public struct OTLPGRPCLogEntryExporterConfiguration: Sendable {
    let endpoint: OTLPGRPCEndpoint
    let headers: HPACKHeaders

    /// Create a configuration for an ``OTLPGRPCLogEntryExporter``.
    ///
    /// - Parameters:
    ///   - environment: The environment variables.
    ///   - endpoint: An optional endpoint string that takes precedence over any environment values. Defaults to `localhost:4317` if `nil`.
    ///   - shouldUseAnInsecureConnection: Whether to use an insecure connection in the absence of a scheme inside an endpoint configuration value.
    ///   - headers: Optional headers that take precedence over any headers configured via environment values.
    public init(
        environment: OTelEnvironment,
        endpoint: String? = nil,
        shouldUseAnInsecureConnection: Bool? = nil,
        headers: HPACKHeaders? = nil
    ) throws {
        let shouldUseAnInsecureConnection = try environment.value(
            programmaticOverride: shouldUseAnInsecureConnection,
            signalSpecificKey: "OTEL_EXPORTER_OTLP_LOGGING_INSECURE",
            sharedKey: "OTEL_EXPORTER_OTLP_INSECURE"
        ) ?? false

        let programmaticEndpoint: OTLPGRPCEndpoint? = try {
            guard let endpoint else { return nil }
            return try OTLPGRPCEndpoint(urlString: endpoint, isInsecure: shouldUseAnInsecureConnection)
        }()

        self.endpoint = try environment.value(
            programmaticOverride: programmaticEndpoint,
            signalSpecificKey: "OTEL_EXPORTER_OTLP_LOGGING_ENDPOINT",
            sharedKey: "OTEL_EXPORTER_OTLP_ENDPOINT",
            transformValue: { value in
                do {
                    return try OTLPGRPCEndpoint(urlString: value, isInsecure: shouldUseAnInsecureConnection)
                } catch {
                    // TODO: Log
                    return nil
                }
            }
        ) ?? .default

        self.headers = try environment.value(
            programmaticOverride: headers,
            signalSpecificKey: "OTEL_EXPORTER_OTLP_LOGGING_HEADERS",
            sharedKey: "OTEL_EXPORTER_OTLP_HEADERS",
            transformValue: { value in
                guard let keyValuePairs = OTelEnvironment.headers(parsingValue: value) else { return nil }
                return HPACKHeaders(keyValuePairs)
            }
        ) ?? [:]
    }
}

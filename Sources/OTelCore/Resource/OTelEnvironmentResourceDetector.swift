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

/// A resource detector parsing resource attributes from the `OTEL_RESOURCE_ATTRIBUTES` environment variable.
public struct OTelEnvironmentResourceDetector: OTelResourceDetector, CustomStringConvertible {
    public let description = "environment"
    private let environment: OTelEnvironment

    /// Create an environment resource detector.
    ///
    /// - Parameter environment: The environment to read `OTEL_RESOURCE_ATTRIBUTES` from.
    public init(environment: OTelEnvironment) {
        self.environment = environment
    }

    public func resource(logger: Logger) throws -> OTelResource {
        let environmentKey = "OTEL_RESOURCE_ATTRIBUTES"
        guard let environmentValue = environment[environmentKey] else { return OTelResource() }

        let attributes: SpanAttributes = try {
            var attributes = SpanAttributes()
            let keyValuePairs = environmentValue.split(separator: ",")

            for keyValuePair in keyValuePairs {
                let parts = keyValuePair.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else {
                    throw OTelEnvironmentResourceAttributeParsingError(keyValuePair: parts)
                }
                attributes["\(parts[0])"] = "\(parts[1])"
            }

            return attributes
        }()

        return OTelResource(attributes: attributes)
    }
}

@_spi(Testing)
public struct OTelEnvironmentResourceAttributeParsingError: Error, Equatable {
    public let keyValuePair: [Substring]

    public init(keyValuePair: [Substring]) {
        self.keyValuePair = keyValuePair
    }
}

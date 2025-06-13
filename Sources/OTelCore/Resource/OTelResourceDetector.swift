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

/// A resource detector asynchronously detects attributes describing an ``OTelResource``.
///
/// [OTel Specification: Resource Creation](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/resource/sdk.md#resource-creation)
public protocol OTelResourceDetector: Sendable {
    /// Detect attributes describing a resource.
    ///
    /// - Important: A successful detection of zero attributes **should not** result in an error being thrown.
    /// Instead, return an empty resource. Only throw an error if the attempt to detect the resource fails.
    ///
    /// - Parameter logger: A logger to be used during resource detection.
    /// - Returns: An ``OTelResource`` detected by this detector.
    func resource(logger: Logger) async throws -> OTelResource
}

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

@_documentation(visibility: private)
public struct OTelManualResourceDetector: OTelResourceDetector, CustomStringConvertible {
    public let description = "manual"
    private let _resource: OTelResource

    init(resource: OTelResource) {
        _resource = resource
    }

    public func resource(logger: Logger) -> OTelResource {
        _resource
    }
}

extension OTelResourceDetector where Self == OTelManualResourceDetector {
    /// Create a manual resource detector.
    ///
    /// This is useful if you want to pass additional resource attributes to ``OTelResourceDetection/init(detectors:timeout:)`` without
    /// the overhead of defining your own ``OTelResourceDetector``.
    ///
    /// - Parameter resource: The resource to return from ``OTelResourceDetector/resource(logger:)``.
    /// - Returns: A resource detector returning the given resource.
    public static func manual(_ resource: OTelResource) -> OTelManualResourceDetector {
        OTelManualResourceDetector(resource: resource)
    }
}

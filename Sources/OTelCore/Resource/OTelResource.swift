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

import Tracing

/// A set of attributes describing the entity being instrumented.
///
/// Resources are immutable, but multiple resources may be merged using ``merging(_:)``.
///
/// [OpenTelemetry Specification: Resource](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/resource/sdk.md#resource-sdk)
public struct OTelResource: Sendable, Equatable {
    /// The attributes describing this resource.
    public let attributes: SpanAttributes

    /// Create a resource described by the given attributes.
    ///
    /// - Parameter attributes: The attributes describing this resource. Defaults to no attributes.
    public init(attributes: SpanAttributes = [:]) {
        self.attributes = attributes
    }

    /// Creates a new resource by merging the attributes of the given resource
    /// into this resource's attributes.
    ///
    /// In case of a duplicate key across both resources, the value from the other resource will be used.
    ///
    /// - Parameter other: The ``OTelResource`` to merge into this one.
    /// - Returns: A new ``OTelResource`` combining the attributes from both resources.
    ///
    /// [OpenTelemetry Specification: Merge Resources](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/resource/sdk.md#merge)
    public func merging(_ other: OTelResource) -> OTelResource {
        var attributes = attributes
        attributes.merge(other.attributes)
        return OTelResource(attributes: attributes)
    }
}

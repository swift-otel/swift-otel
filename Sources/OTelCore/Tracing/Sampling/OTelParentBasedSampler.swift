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
import W3CTraceContext

/// A sampler relaying a sampling decision to any of the configured samplers,
/// based on whether a given span has a remote and/or sampled parent.
///
/// ## Delegation
/// | Has parent | Remote parent | Parent sampled | Sampler |
/// | --- | --- | --- | --- |
/// | ❌ | ❌ | ❌ | ``rootSampler`` |
/// | ✅ | ✅ | ✅ | ``remoteParentSampledSampler`` |
/// | ✅ | ✅ | ❌ | ``remoteParentNotSampledSampler`` |
/// | ✅ | ❌ | ✅ | ``localParentSampledSampler`` |
/// | ✅ | ❌ | ❌ | ``localParentNotSampledSampler`` |
public struct OTelParentBasedSampler: OTelSampler {
    /// The sampler invoked if a given span does not have a parent.
    public let rootSampler: any OTelSampler

    /// The sampler invoked if a given span has a remote parent span that's sampled.
    public let remoteParentSampledSampler: any OTelSampler

    /// The sampler invoked if a given span has a remote parent span that's not sampled.
    public let remoteParentNotSampledSampler: any OTelSampler

    /// The sampler invoked if a given span has a local parent span that's sampled.
    public let localParentSampledSampler: any OTelSampler

    /// The sampler invoked if a given span has a local parent span that's not sampled.
    public let localParentNotSampledSampler: any OTelSampler

    /// Create a parent-based sampler delegating to the given samplers.
    ///
    /// - Parameters:
    ///   - rootSampler: The sampler to invoke if a given span does not have a parent.
    ///   - remoteParentSampledSampler: The sampler to invoke if a given span has a remote parent span that's sampled.
    ///   Defaults to a constantly sampling sampler.
    ///   - remoteParentNotSampledSampler: The sampler to invoke if a given span has a remote parent span that's not sampled.
    ///   Defaults to a constantly dropping sampler.
    ///   - localParentSampledSampler: The sampler to invoke if a given span has a local parent span that's sampled.
    ///   Defaults to a constantly sampling sampler.
    ///   - localParentNotSampledSampler: The sampler to invoke if a given span has a local parent span that's not sampled.
    ///   Defaults to a constantly dropping sampler.
    public init(
        rootSampler: any OTelSampler,
        remoteParentSampledSampler: any OTelSampler = OTelConstantSampler(isOn: true),
        remoteParentNotSampledSampler: any OTelSampler = OTelConstantSampler(isOn: false),
        localParentSampledSampler: any OTelSampler = OTelConstantSampler(isOn: true),
        localParentNotSampledSampler: any OTelSampler = OTelConstantSampler(isOn: false)
    ) {
        self.rootSampler = rootSampler
        self.remoteParentSampledSampler = remoteParentSampledSampler
        self.remoteParentNotSampledSampler = remoteParentNotSampledSampler
        self.localParentSampledSampler = localParentSampledSampler
        self.localParentNotSampledSampler = localParentNotSampledSampler
    }

    public func samplingResult(
        operationName: String,
        kind: SpanKind,
        traceID: TraceID,
        attributes: SpanAttributes,
        links: [SpanLink],
        parentContext: ServiceContext
    ) -> OTelSamplingResult {
        func samplingResult(from sampler: any OTelSampler) -> OTelSamplingResult {
            sampler.samplingResult(
                operationName: operationName,
                kind: kind,
                traceID: traceID,
                attributes: attributes,
                links: links,
                parentContext: parentContext
            )
        }

        guard let parentContext = parentContext.spanContext else {
            return samplingResult(from: rootSampler)
        }

        switch (parentContext.isRemote, parentContext.traceFlags.contains(.sampled)) {
        case (true, true):
            return samplingResult(from: remoteParentSampledSampler)
        case (true, false):
            return samplingResult(from: remoteParentNotSampledSampler)
        case (false, true):
            return samplingResult(from: localParentSampledSampler)
        case (false, false):
            return samplingResult(from: localParentNotSampledSampler)
        }
    }
}

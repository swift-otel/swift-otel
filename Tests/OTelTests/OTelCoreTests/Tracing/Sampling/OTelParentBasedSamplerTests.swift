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

import NIOConcurrencyHelpers
@testable import OTel
import Tracing
import W3CTraceContext
import XCTest

final class OTelParentBasedSamplerTests: XCTestCase {
    private var rootSampler: RecordingSampler!
    private var remoteParentSampledSampler: RecordingSampler!
    private var remoteParentNotSampledSampler: RecordingSampler!
    private var localParentSampledSampler: RecordingSampler!
    private var localParentNotSampledSampler: RecordingSampler!

    override func setUp() {
        rootSampler = RecordingSampler(sampler: OTelConstantSampler(isOn: false))
        remoteParentSampledSampler = RecordingSampler(sampler: OTelConstantSampler(isOn: false))
        remoteParentNotSampledSampler = RecordingSampler(sampler: OTelConstantSampler(isOn: false))
        localParentSampledSampler = RecordingSampler(sampler: OTelConstantSampler(isOn: false))
        localParentNotSampledSampler = RecordingSampler(sampler: OTelConstantSampler(isOn: false))
    }

    func test_samplingResult_withoutParent_invokesRootSampler() {
        rootSampler = RecordingSampler(sampler: OTelConstantSampler(isOn: true))
        let sampler = sampler()

        let result = sampler.samplingResult(
            operationName: "does-not-matter",
            kind: .internal,
            traceID: .allZeroes,
            attributes: [:],
            links: [],
            parentContext: .topLevel
        )

        XCTAssertEqual(result, OTelSamplingResult(decision: .recordAndSample, attributes: [:]))
        XCTAssertEqual(rootSampler.results, [result])
    }

    func test_samplingResult_withSampledRemoteParent_invokesRemoteParentSampledSampler() {
        remoteParentSampledSampler = RecordingSampler(sampler: OTelConstantSampler(isOn: true))
        let sampler = sampler()

        var parentContext = ServiceContext.topLevel
        parentContext.spanContext = .remoteStub(traceFlags: .sampled)

        let result = sampler.samplingResult(
            operationName: "does-not-matter",
            kind: .internal,
            traceID: .allZeroes,
            attributes: [:],
            links: [],
            parentContext: parentContext
        )

        XCTAssertEqual(result, OTelSamplingResult(decision: .recordAndSample, attributes: [:]))
        XCTAssertEqual(remoteParentSampledSampler.results, [result])
    }

    func test_samplingResult_withNonSampledRemoteParent_invokesRemoteParentNotSampledSampler() {
        remoteParentNotSampledSampler = RecordingSampler(sampler: OTelConstantSampler(isOn: true))
        let sampler = sampler()

        var parentContext = ServiceContext.topLevel
        parentContext.spanContext = .remoteStub(traceFlags: [])

        let result = sampler.samplingResult(
            operationName: "does-not-matter",
            kind: .internal,
            traceID: .allZeroes,
            attributes: [:],
            links: [],
            parentContext: parentContext
        )

        XCTAssertEqual(result, OTelSamplingResult(decision: .recordAndSample, attributes: [:]))
        XCTAssertEqual(remoteParentNotSampledSampler.results, [result])
    }

    func test_samplingResult_withSampledLocalParent_invokesLocalParentSampledSampler() {
        localParentSampledSampler = RecordingSampler(sampler: OTelConstantSampler(isOn: true))
        let sampler = sampler()

        var parentContext = ServiceContext.topLevel
        parentContext.spanContext = .localStub(traceFlags: .sampled)

        let result = sampler.samplingResult(
            operationName: "does-not-matter",
            kind: .internal,
            traceID: .allZeroes,
            attributes: [:],
            links: [],
            parentContext: parentContext
        )

        XCTAssertEqual(result, OTelSamplingResult(decision: .recordAndSample, attributes: [:]))
        XCTAssertEqual(localParentSampledSampler.results, [result])
    }

    func test_samplingResult_withNonSampledLocalParent_invokesLocalParentNotSampledSampler() {
        localParentNotSampledSampler = RecordingSampler(sampler: OTelConstantSampler(isOn: true))
        let sampler = sampler()

        var parentContext = ServiceContext.topLevel
        parentContext.spanContext = .localStub(traceFlags: [])

        let result = sampler.samplingResult(
            operationName: "does-not-matter",
            kind: .internal,
            traceID: .allZeroes,
            attributes: [:],
            links: [],
            parentContext: parentContext
        )

        XCTAssertEqual(result, OTelSamplingResult(decision: .recordAndSample, attributes: [:]))
        XCTAssertEqual(localParentNotSampledSampler.results, [result])
    }

    private func sampler() -> OTelParentBasedSampler {
        OTelParentBasedSampler(
            rootSampler: rootSampler,
            remoteParentSampledSampler: remoteParentSampledSampler,
            remoteParentNotSampledSampler: remoteParentNotSampledSampler,
            localParentSampledSampler: localParentSampledSampler,
            localParentNotSampledSampler: localParentNotSampledSampler
        )
    }
}

// MARK: - Helpers

private final class RecordingSampler: OTelSampler {
    private let sampler: any OTelSampler
    private let _results = NIOLockedValueBox([OTelSamplingResult]())
    var results: [OTelSamplingResult] { _results.withLockedValue { $0 } }

    init(sampler: any OTelSampler) {
        self.sampler = sampler
    }

    func samplingResult(
        operationName: String,
        kind: SpanKind,
        traceID: TraceID,
        attributes: SpanAttributes,
        links: [SpanLink],
        parentContext: ServiceContext
    ) -> OTelSamplingResult {
        let result = sampler.samplingResult(
            operationName: operationName,
            kind: kind,
            traceID: traceID,
            attributes: attributes,
            links: links,
            parentContext: parentContext
        )
        _results.withLockedValue { $0.append(result) }
        return result
    }
}

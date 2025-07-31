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

@testable import OTel
import Tracing
import XCTest

final class OTelConstantSamplerTests: XCTestCase {
    func test_init_isOn_decidesToRecordAndSample() {
        let sampler = OTelConstantSampler(isOn: true)

        let result = sampler.samplingResult(
            operationName: "does-not-matter",
            kind: .internal,
            traceID: .allZeroes,
            attributes: [:],
            links: [],
            parentContext: .topLevel
        )

        XCTAssertEqual(result, OTelSamplingResult(decision: .recordAndSample, attributes: [:]))
    }

    func test_init_isOff_decidesToDrop() {
        let sampler = OTelConstantSampler(isOn: false)

        let result = sampler.samplingResult(
            operationName: "does-not-matter",
            kind: .internal,
            traceID: .allZeroes,
            attributes: [:],
            links: [],
            parentContext: .topLevel
        )

        XCTAssertEqual(result, OTelSamplingResult(decision: .drop, attributes: [:]))
    }

    func test_init_record_decidesToRecord() {
        let sampler = OTelConstantSampler(decision: .record)

        let result = sampler.samplingResult(
            operationName: "does-not-matter",
            kind: .internal,
            traceID: .allZeroes,
            attributes: [:],
            links: [],
            parentContext: .topLevel
        )

        XCTAssertEqual(result, OTelSamplingResult(decision: .record, attributes: [:]))
    }
}

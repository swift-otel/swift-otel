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
import OTelCore
import OTelTesting
import XCTest

final class OTelResourceDetectionTests: XCTestCase {
    func test_resource_includesSDKAttributes() async {
        let resourceDetection = OTelResourceDetection(detectors: [])
        let environment = OTelEnvironment()

        let resource = await resourceDetection.resource(environment: environment, logLevel: .trace)

        XCTAssertEqual(resource.attributes["telemetry.sdk.version"]?.toSpanAttribute(), .string(OTelLibrary.version))
        XCTAssertEqual(resource.attributes["telemetry.sdk.name"]?.toSpanAttribute(), "opentelemetry")
        XCTAssertEqual(resource.attributes["telemetry.sdk.language"]?.toSpanAttribute(), "swift")
    }

    func test_resource_appliesDetectedResourceAttributesInOrder() async {
        let environment = OTelEnvironment()

        let resourceA = OTelResource(attributes: ["1": "a", "2": "a", "3": "a"])
        let resourceB = OTelResource(attributes: ["2": "b", "3": "b"])
        let resourceC = OTelResource(attributes: ["3": "c"])

        let resourceDetectorA = ResourceDetectorMock(description: "a", result: .success(resourceA))
        let resourceDetectorB = ResourceDetectorMock(description: "b", result: .success(resourceB))
        let resourceDetectorC = ResourceDetectorMock(description: "c", result: .success(resourceC))

        let resourceDetection = OTelResourceDetection(
            detectors: [resourceDetectorA, resourceDetectorB, resourceDetectorC]
        )

        let resource = await resourceDetection.resource(environment: environment, logLevel: .trace)

        XCTAssertEqual(resource.attributes["1"]?.toSpanAttribute(), "a")
        XCTAssertEqual(resource.attributes["2"]?.toSpanAttribute(), "b")
        XCTAssertEqual(resource.attributes["3"]?.toSpanAttribute(), "c")
    }

    func test_resource_whenResourceDetectorFails_stillUsesAttributesFromSuccessfulDetectors() async {
        let environment = OTelEnvironment()

        let resourceA = OTelResource(attributes: ["a": "a"])
        let resourceB = OTelResource(attributes: ["b": "b"])

        let resourceDetectorA = ResourceDetectorMock(description: "a", result: .success(resourceA))
        let resourceDetectorB = ResourceDetectorMock(description: "b", result: .success(resourceB))
        let resourceDetectorC = ResourceDetectorMock(description: "c", result: .failure(TestError()))

        let resourceDetection = OTelResourceDetection(
            detectors: [resourceDetectorA, resourceDetectorB, resourceDetectorC]
        )

        let resource = await resourceDetection.resource(environment: environment, logLevel: .trace)

        XCTAssertEqual(resource.attributes["a"]?.toSpanAttribute(), "a")
        XCTAssertEqual(resource.attributes["b"]?.toSpanAttribute(), "b")
    }

    func test_resource_whenDetectionTimesOut_discardsDetectedResourceAttributes() async {
        let environment = OTelEnvironment()

        let clock = TestClock()
        var sleeps = clock.sleepCalls.makeAsyncIterator()

        let resourceA = OTelResource(attributes: ["a": "a"])
        let resourceDetectorA = ResourceDetectorMock(description: "a", result: .success(resourceA))
        let resourceDetectorB = SleepingResourceDetector()

        let resourceDetection = OTelResourceDetection(
            detectors: [resourceDetectorA, resourceDetectorB],
            timeout: .seconds(1),
            clock: clock
        )

        let finishExpectation = expectation(description: "Expected resource detection to finish after timeout.")
        Task {
            let resource = await resourceDetection.resource(environment: environment, logLevel: .trace)
            XCTAssertNil(resource.attributes["a"])
            finishExpectation.fulfill()
        }

        // advance past timeout
        await sleeps.next()
        clock.advance(by: .seconds(2))

        await fulfillment(of: [finishExpectation], timeout: 0.1)
    }

    func test_resource_withServiceNameEnvironmentVariable_addsProvidedServiceName() async {
        let environment = OTelEnvironment(values: ["OTEL_SERVICE_NAME": "environment"])

        let resourceA = OTelResource(attributes: ["sercice.name": "resource"])
        let resourceDetector = ResourceDetectorMock(description: "a", result: .success(resourceA))

        let resourceDetection = OTelResourceDetection(detectors: [resourceDetector])

        let resource = await resourceDetection.resource(environment: environment, logLevel: .trace)

        XCTAssertEqual(resource.attributes["service.name"]?.toSpanAttribute(), "environment")
    }

    func test_resource_withServiceNameResourceAttribute_addsProvidedServiceName() async {
        let environment = OTelEnvironment()

        let resourceA = OTelResource(attributes: ["service.name": "resource"])
        let resourceDetector = ResourceDetectorMock(description: "a", result: .success(resourceA))

        let resourceDetection = OTelResourceDetection(detectors: [resourceDetector])

        let resource = await resourceDetection.resource(environment: environment, logLevel: .trace)

        XCTAssertEqual(resource.attributes["service.name"]?.toSpanAttribute(), "resource")
    }

    func test_resource_withExecutableNameResourceAttribute_addsFallbackServiceName() async {
        let environment = OTelEnvironment()

        let resourceA = OTelResource(attributes: ["process.executable.name": "awesome_executable"])
        let resourceDetector = ResourceDetectorMock(description: "a", result: .success(resourceA))

        let resourceDetection = OTelResourceDetection(detectors: [resourceDetector])

        let resource = await resourceDetection.resource(environment: environment, logLevel: .trace)

        XCTAssertEqual(resource.attributes["service.name"]?.toSpanAttribute(), "unknown_service:awesome_executable")
    }

    func test_resource_withoutExecutableNameResourceAttribute_addsFallbackServiceName() async {
        let environment = OTelEnvironment()

        let resourceDetection = OTelResourceDetection(detectors: [])

        let resource = await resourceDetection.resource(environment: environment, logLevel: .trace)

        XCTAssertEqual(resource.attributes["service.name"]?.toSpanAttribute(), "unknown_service")
    }
}

private struct ResourceDetectorMock: OTelResourceDetector {
    let description: String
    private let result: Result<OTelResource, Error>

    init(description: String, result: Result<OTelResource, Error>) {
        self.description = description
        self.result = result
    }

    func resource(logger: Logger) async throws -> OTelResource {
        try result.get()
    }
}

private struct SleepingResourceDetector: OTelResourceDetector {
    let description = "😴"

    func resource(logger: Logger) async throws -> OTelResource {
        try await Task.sleep(for: .seconds(3))
        throw CancellationError()
    }
}

private struct TestError: Error {}

extension OTelResourceDetection {
    // Overload with logging disabled.
    func resource(environment: OTelEnvironment, logLevel: Logger.Level = .info) async -> OTelResource {
        await resource(environment: environment, logger: ._otelDisabled, logLevel: .trace)
    }
}

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
import Tracing
import XCTest

final class OTelEnvironmentResourceDetectorTests: XCTestCase {
    override func setUp() {
        LoggingSystem.bootstrapInternal(logLevel: .trace)
    }

    func test_resource_withValidEnvironmentVariable_returnsResource() throws {
        let environment = OTelEnvironment(values: [
            "OTEL_RESOURCE_ATTRIBUTES": "service.name=test,service.version=1.2.3",
        ])
        let detector = OTelEnvironmentResourceDetector(environment: environment)

        let resource = try detector.resource(logger: Logger(label: #function))

        XCTAssertEqual(resource, OTelResource(attributes: ["service.name": "test", "service.version": "1.2.3"]))
    }

    func test_resource_withoutEnvironmentVariable_returnsEmptyResource() throws {
        let environment = OTelEnvironment()
        let detector = OTelEnvironmentResourceDetector(environment: environment)

        let resource = try detector.resource(logger: Logger(label: #function))

        XCTAssertEqual(resource, OTelResource())
    }

    func test_resource_withEmptyEnvironmentValue_returnsEmptyResource() throws {
        let environment = OTelEnvironment(values: ["OTEL_RESOURCE_ATTRIBUTES": ""])
        let detector = OTelEnvironmentResourceDetector(environment: environment)

        let resource = try detector.resource(logger: Logger(label: #function))

        XCTAssertEqual(resource, OTelResource())
    }

    func test_resource_withMalformedEnvironmentValue_throwsError() throws {
        let environment = OTelEnvironment(
            values: ["OTEL_RESOURCE_ATTRIBUTES": "service.name=test,service.version,service.id=42"]
        )
        let detector = OTelEnvironmentResourceDetector(environment: environment)

        do {
            let resource = try detector.resource(logger: Logger(label: #function))
            XCTFail("Expected error, got resource: \(resource)")
        } catch let error as OTelEnvironmentResourceAttributeParsingError {
            XCTAssertEqual(error, .init(keyValuePair: ["service.version"]))
        }
    }
}

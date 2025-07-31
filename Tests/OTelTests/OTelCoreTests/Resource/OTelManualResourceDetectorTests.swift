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

final class OTelManualResourceDetectorTests: XCTestCase {
    func test_resource_returnsProvidedResource() async throws {
        let resource = OTelResource(attributes: ["foo": "bar"])

        let resourceDetector: any OTelResourceDetector = .manual(resource)
        let detectedResource = try await resourceDetector.resource(logger: Logger(label: #function))

        XCTAssertEqual(resource, detectedResource)
    }
}

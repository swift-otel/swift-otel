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

@testable import OTLPGRPC
import XCTest

final class OTLPGRPCEndpointTests: XCTestCase {
    func test_init_withHTTPScheme_withoutisInsecure_returnsInsecureEndpoint() throws {
        XCTAssertEqual(
            try OTLPGRPCEndpoint(urlString: "http://test:1234", isInsecure: nil),
            OTLPGRPCEndpoint(host: "test", port: 1234, isInsecure: true)
        )
    }

    func test_init_withHTTPScheme_withisInsecure_returnsInsecureEndpoint() throws {
        XCTAssertEqual(
            try OTLPGRPCEndpoint(urlString: "http://test:1234", isInsecure: true),
            OTLPGRPCEndpoint(host: "test", port: 1234, isInsecure: true)
        )
    }

    func test_init_withHTTPSScheme_withoutisInsecure_returnsSecureEndpoint() throws {
        XCTAssertEqual(
            try OTLPGRPCEndpoint(urlString: "https://test:1234", isInsecure: nil),
            OTLPGRPCEndpoint(host: "test", port: 1234, isInsecure: false)
        )
    }

    func test_init_withHTTPSScheme_withIsInsecure_returnsSecureEndpoint() throws {
        XCTAssertEqual(
            try OTLPGRPCEndpoint(urlString: "https://test:1234", isInsecure: false),
            OTLPGRPCEndpoint(host: "test", port: 1234, isInsecure: false)
        )
    }

    func test_init_withEmptyString_returnsDefaultEndpoint() throws {
        XCTAssertEqual(
            try OTLPGRPCEndpoint(urlString: "", isInsecure: nil),
            .default
        )
    }

    func test_init_withInvalidURLString_throwsOTLPGRPCEndpointConfigurationError() throws {
        do {
            let endpoint = try OTLPGRPCEndpoint(urlString: "not-a-url", isInsecure: nil)
            XCTFail("Expected configuration error, got endpoint: \(endpoint)")
        } catch let error as OTLPGRPCEndpointConfigurationError {
            XCTAssertEqual(error.value, "not-a-url")
        }
    }

    func test_init_withoutScheme_withoutisInsecure_returnsSecureEndpoint() throws {
        XCTAssertEqual(
            try OTLPGRPCEndpoint(urlString: "test:1234", isInsecure: nil),
            OTLPGRPCEndpoint(host: "test", port: 1234, isInsecure: false)
        )
    }

    func test_init_withoutScheme_withisInsecure_returnsSecureEndpoint() throws {
        XCTAssertEqual(
            try OTLPGRPCEndpoint(urlString: "test:1234", isInsecure: true),
            OTLPGRPCEndpoint(host: "test", port: 1234, isInsecure: true)
        )
    }

    func test_init_withoutScheme_withIsInsecure_returnsInsecureEndpoint() throws {
        XCTAssertEqual(
            try OTLPGRPCEndpoint(urlString: "test:1234", isInsecure: false),
            OTLPGRPCEndpoint(host: "test", port: 1234, isInsecure: false)
        )
    }
}

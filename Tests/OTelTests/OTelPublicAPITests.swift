//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2025 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import OTel // NOTE: Not @testable import, to test public API visibility.
import Testing

@Suite struct OTelPublicAPITests {
    @Test func testBootstrap() {
        let error = #expect(throws: (any Error).self) {
            try OTel.bootstrap()
        }
        #expect((error as? CustomStringConvertible)?.description == "Not implemented")
    }

    @Test func testMakeLoggingBackend() {
        let error = #expect(throws: (any Error).self) {
            try OTel.makeLoggingBackend()
        }
        #expect((error as? CustomStringConvertible)?.description == "Not implemented")
    }

    @Test func testMakeMetricsBackend() throws {
        _ = try OTel.makeMetricsBackend()
    }

    @Test func testMakeTracingBackend() {
        let error = #expect(throws: (any Error).self) {
            try OTel.makeTracingBackend()
        }
        #expect((error as? CustomStringConvertible)?.description == "Not implemented")
    }
}

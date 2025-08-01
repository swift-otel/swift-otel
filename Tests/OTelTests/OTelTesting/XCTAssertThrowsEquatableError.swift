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

#if canImport(XCTest)
import XCTest

func XCTAssertThrowsError<E: Error & Equatable>(_ expression: @autoclosure () throws -> some Any, _ error: E) {
    do {
        let value = try expression()
        XCTFail("Expected error but received value: \(value)")
    } catch let actualError {
        guard let e = actualError as? E else {
            XCTFail("Expected \(type(of: E.self)), but received \(type(of: actualError))")
            return
        }
        XCTAssertEqual(e, error)
    }
}
#endif

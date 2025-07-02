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

package import W3CTraceContext

extension SpanID {
    /// A stub span ID for testing with bytes from one to eight.
    package static let oneToEight = SpanID(bytes: .init((1, 2, 3, 4, 5, 6, 7, 8)))

    /// A stub span ID for testing with all bytes being zero.
    package static let allZeroes = SpanID(bytes: .init((0, 0, 0, 0, 0, 0, 0, 0)))
}

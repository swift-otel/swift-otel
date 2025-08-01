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

import W3CTraceContext

extension TraceID {
    /// A trace ID stub with bytes from one to sixteen.
    static let oneToSixteen = TraceID(bytes: .init((1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)))

    /// A trace ID stub with all bytes being zero.
    static let allZeroes = TraceID(bytes: .init((0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)))
}

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2023 Moritz Lang and the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import OpenTelemetry

extension OTelSpanID {
    /// A stub span ID for testing with bytes from one to eight.
    public static let oneToEight = OTelSpanID(bytes: (1, 2, 3, 4, 5, 6, 7, 8))

    /// A stub span ID for testing with all bytes being zero.
    public static let allZeroes = OTelSpanID(bytes: (0, 0, 0, 0, 0, 0, 0, 0))
}

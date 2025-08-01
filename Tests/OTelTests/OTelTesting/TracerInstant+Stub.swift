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

import Tracing

struct StubInstant: TracerInstant {
    var nanosecondsSinceEpoch: UInt64

    static func < (lhs: StubInstant, rhs: StubInstant) -> Bool {
        lhs.nanosecondsSinceEpoch < rhs.nanosecondsSinceEpoch
    }
}

extension TracerInstant where Self == StubInstant {
    /// Create a tracer instant with the given nanoseconds since epoch.
    ///
    /// - Parameter nanosecondsSinceEpoch: The fixed nanoseconds since epoch.
    /// - Returns: A tracer instant with the given nanoseconds since epoch.
    static func constant(_ nanosecondsSinceEpoch: UInt64) -> StubInstant {
        StubInstant(nanosecondsSinceEpoch: nanosecondsSinceEpoch)
    }
}

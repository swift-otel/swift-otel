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

package struct StubInstant: TracerInstant {
    package var nanosecondsSinceEpoch: UInt64

    package static func < (lhs: StubInstant, rhs: StubInstant) -> Bool {
        lhs.nanosecondsSinceEpoch < rhs.nanosecondsSinceEpoch
    }
}

extension TracerInstant where Self == StubInstant {
    /// Create a tracer instant with the given nanoseconds since epoch.
    ///
    /// - Parameter nanosecondsSinceEpoch: The fixed nanoseconds since epoch.
    /// - Returns: A tracer instant with the given nanoseconds since epoch.
    package static func constant(_ nanosecondsSinceEpoch: UInt64) -> StubInstant {
        StubInstant(nanosecondsSinceEpoch: nanosecondsSinceEpoch)
    }
}

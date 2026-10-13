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

import Instrumentation

private enum StubContextKey: InstrumentationContextKey {
    typealias Value = Int
}

extension InstrumentationContext {
    /// A stub integer value used for testing.
    var stubValue: Int? {
        get {
            self[StubContextKey.self]
        }
        set {
            self[StubContextKey.self] = newValue
        }
    }

    /// A top-level instrumentation context with `stubValue` set to the given value.
    ///
    /// - Parameter value: The value to use for ``stubValue``.
    /// - Returns: A top-level instrumentation context with `stubValue` set to the given value.
    static func withStubValue(_ value: Int) -> InstrumentationContext {
        var context = InstrumentationContext.topLevel
        context.stubValue = value
        return context
    }
}

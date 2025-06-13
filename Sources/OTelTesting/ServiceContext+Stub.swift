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

import ServiceContextModule

private enum StubContextKey: ServiceContextKey {
    typealias Value = Int
}

extension ServiceContext {
    /// A stub integer value used for testing.
    package var stubValue: Int? {
        get {
            self[StubContextKey.self]
        }
        set {
            self[StubContextKey.self] = newValue
        }
    }

    /// A top-level service context with `stubValue` set to the given value.
    ///
    /// - Parameter value: The value to use for ``stubValue``.
    /// - Returns: A top-level service context with `stubValue` set to the given value.
    package static func withStubValue(_ value: Int) -> ServiceContext {
        var context = ServiceContext.topLevel
        context.stubValue = value
        return context
    }
}

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

public import ServiceContextModule
import W3CTraceContext

extension ServiceContext {
    /// A Boolean value indicating whether the span associated with this service context is sampled.
    ///
    /// Returns `false` if there is no span context.
    public var otelIsSampled: Bool {
        spanContext?.traceFlags.contains(.sampled) ?? false
    }
}

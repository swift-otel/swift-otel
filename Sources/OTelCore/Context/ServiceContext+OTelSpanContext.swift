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
import W3CTraceContext

extension ServiceContext {
    /// The span context.
    public internal(set) var spanContext: OTelSpanContext? {
        get {
            self[SpanContextKey.self]
        }
        set {
            self[SpanContextKey.self] = newValue
        }
    }
}

private enum SpanContextKey: ServiceContextKey {
    typealias Value = OTelSpanContext

    static let nameOverride: String? = "otel-span-context"
}

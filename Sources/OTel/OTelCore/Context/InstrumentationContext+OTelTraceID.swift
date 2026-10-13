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

public import Instrumentation

extension InstrumentationContext {
    /// A hex string representation of this instrumentation context's trace ID.
    public var otelTraceID: String? {
        spanContext?.traceID.description
    }
}

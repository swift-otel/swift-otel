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

@testable import OTel
import W3CTraceContext

struct OTelConstantIDGenerator: OTelIDGenerator {
    private let _traceID: TraceID
    private let _spanID: SpanID

    init(traceID: TraceID, spanID: SpanID) {
        _traceID = traceID
        _spanID = spanID
    }

    func nextTraceID() -> TraceID {
        _traceID
    }

    func nextSpanID() -> SpanID {
        _spanID
    }
}

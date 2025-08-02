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

#if !(OTLPHTTP || OTLPGRPC)
// Empty when above trait(s) are disabled.
#else
import Tracing

extension Opentelemetry_Proto_Trace_V1_Status {
    /// Create a status by casting a `SpanStatus`.
    ///
    /// - Parameter status: The `SpanStatus` to cast.
    init(_ status: SpanStatus) {
        self = .with {
            switch status.code {
            case .ok:
                $0.code = .ok
            case .error:
                $0.code = .error
            }
            $0.message = status.message ?? ""
        }
    }
}
#endif

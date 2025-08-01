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
import struct Foundation.Data
import W3CTraceContext

extension TraceID {
    var data: Data {
        Data(bytes)
    }
}
#endif

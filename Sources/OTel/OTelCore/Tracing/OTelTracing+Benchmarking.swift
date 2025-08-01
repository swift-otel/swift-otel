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

extension ServiceContext {
    static func withSpanContext(_ spanContext: OTelSpanContext) -> Self {
        var context = ServiceContext.topLevel
        context.spanContext = spanContext
        return context
    }
}

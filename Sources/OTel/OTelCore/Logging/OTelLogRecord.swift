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

import Logging

struct OTelLogRecord: Equatable, Sendable {
    var body: Logger.Message
    var level: Logger.Level
    var metadata: Logger.Metadata
    var timeNanosecondsSinceEpoch: UInt64

    let resource: OTelResource
    let spanContext: OTelSpanContext?

    init(
        body: Logger.Message,
        level: Logger.Level,
        metadata: Logger.Metadata,
        timeNanosecondsSinceEpoch: UInt64,
        resource: OTelResource,
        spanContext: OTelSpanContext?
    ) {
        self.body = body
        self.level = level
        self.metadata = metadata
        self.timeNanosecondsSinceEpoch = timeNanosecondsSinceEpoch
        self.resource = resource
        self.spanContext = spanContext
    }
}

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

@_spi(Logging)
public struct OTelLogRecord: Equatable, Sendable {
    public var body: Logger.Message
    public var level: Logger.Level
    public var metadata: Logger.Metadata
    public var timeNanosecondsSinceEpoch: UInt64

    public let resource: OTelResource
    public let spanContext: OTelSpanContext?

    package init(
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

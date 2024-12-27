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

@_spi(Logging) import OTel
import Logging
import Foundation

@_spi(Logging)
extension OTelLogRecord {
    public static func stub(
        body: Logger.Message = "🏎️",
        level: Logger.Level = .info,
        metadata: Logger.Metadata = [:],
        timeNanosecondsSinceEpoch: UInt64 = 0,
        resource: OTelResource = OTelResource(),
        spanContext: OTelSpanContext? = nil
    ) -> OTelLogRecord {
        OTelLogRecord(
            body: body,
            level: level,
            metadata: metadata,
            timeNanosecondsSinceEpoch: timeNanosecondsSinceEpoch,
            resource: resource,
            spanContext: spanContext
        )
    }
} 
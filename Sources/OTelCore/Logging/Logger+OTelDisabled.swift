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

extension Logger {
    public static let _otelDisabled = Logger(
        label: "swift-otel-logging-disabled",
        factory: { _ in SwiftLogNoOpLogHandler() }
    )
}

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

import CoreMetrics

extension Histogram: _SwiftMetricsSendableProtocol {}

extension Histogram: CoreMetrics.TimerHandler where Value == Duration {
    func recordNanoseconds(_ duration: Int64) {
        let value = Duration.nanoseconds(duration)
        record(value)
    }
}

extension Histogram: CoreMetrics.RecorderHandler where Value == Double {
    func record(_ value: Int64) {
        record(Double(value))
    }
}

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2026 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import CoreMetrics

extension ExponentialHistogram: _SwiftMetricsSendableProtocol {}

extension ExponentialHistogram: CoreMetrics.TimerHandler where Value == Duration {
    func recordNanoseconds(_ duration: Int64) {
        record(Duration.nanoseconds(duration))
    }
}

extension ExponentialHistogram: CoreMetrics.RecorderHandler where Value == Double {
    func record(_ value: Int64) {
        record(Double(value))
    }
}

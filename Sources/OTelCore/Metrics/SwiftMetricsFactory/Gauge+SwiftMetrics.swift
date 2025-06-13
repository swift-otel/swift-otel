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

extension Gauge: CoreMetrics.RecorderHandler {
    func record(_ value: Int64) {
        record(Double(value))
    }

    func record(_ value: Double) {
        set(to: value)
    }
}

extension Gauge: CoreMetrics.MeterHandler {
    func set(_ value: Double) {
        set(to: value)
    }

    func set(_ value: Int64) {
        set(to: Double(value))
    }
}

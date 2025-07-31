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

/// A type that can be measured to produce an OTel metric data point.
protocol OTelMetricInstrument {
    /// Returns an OTel metric data point for the metric's current state.
    func measure() -> OTelMetricPoint
}

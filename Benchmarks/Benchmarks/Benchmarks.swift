//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2025 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Benchmark
import OTel
import Tracing

let benchmarks: @Sendable () -> Void = {
    let defaultMetrics: [BenchmarkMetric] = [.mallocCountTotal, .cpuTotal]

    Benchmark(
        "withSpan-alwaysOn",
        configuration: Benchmark.Configuration(
            metrics: defaultMetrics,
            scalingFactor: .mega,
            maxDuration: .seconds(10_000_000),
            maxIterations: 3
        )
    ) { benchmark in
        var config = OTel.Configuration.default
        config.traces.sampler = .alwaysOn
        let (backend, _) = try OTel.makeTracingBackend(configuration: config)

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            backend.withSpan("span") { span in blackHole(span) }
        }
    }

    Benchmark(
        "withSpan-alwaysOff",
        configuration: Benchmark.Configuration(
            metrics: defaultMetrics,
            scalingFactor: .mega,
            maxDuration: .seconds(10_000_000),
            maxIterations: 3
        )
    ) { benchmark in
        var config = OTel.Configuration.default
        config.traces.sampler = .alwaysOff
        let (backend, _) = try OTel.makeTracingBackend(configuration: config)

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            backend.withSpan("span") { span in blackHole(span) }
        }
    }
}

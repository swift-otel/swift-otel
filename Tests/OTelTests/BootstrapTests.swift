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

import Metrics
import OTel // NOTE: Not @testable import, to test public API visibility.
import Testing
import Tracing

@Suite struct OTelBootstrapTests {
    @Test func testMakeMetricsBackend() async throws {
        await #expect(processExitsWith: .success, "Running in a separate process because test uses bootstrap") {
            let (factory, _) = try OTel.makeMetricsBackend()
            MetricsSystem.bootstrap(factory)
        }
    }

    @Test func testMakeTracingBackend() async throws {
        await #expect(processExitsWith: .success, "Running in a separate process because test uses bootstrap") {
            let (factory, _) = try OTel.makeTracingBackend()
            InstrumentationSystem.bootstrap(factory)
        }
    }

    @Test func testBootstrapMetricsBackend() async throws {
        // Bootstrapping once succeeds.
        await #expect(processExitsWith: .success, "Running in a separate process because test uses bootstrap") {
            var config = OTel.Configuration.default
            config.logs.enabled = false
            config.metrics.enabled = true
            config.traces.enabled = false
            _ = try OTel.bootstrap(configuration: config)
        }
        // We test the bootstrap API actually did bootstrap, by attempting a second bootstrap.
        await #expect(processExitsWith: .failure, "Running in a separate process because test uses bootstrap") {
            var config = OTel.Configuration.default
            config.logs.enabled = false
            config.metrics.enabled = true
            config.traces.enabled = false
            _ = try OTel.bootstrap(configuration: config)
            MetricsSystem.bootstrap(NOOPMetricsHandler.instance)
        }
    }

    @Test func testBootstrapTracingBackend() async throws {
        // Bootstrapping once succeeds.
        await #expect(processExitsWith: .success, "Running in a separate process because test uses bootstrap") {
            var config = OTel.Configuration.default
            config.logs.enabled = false
            config.metrics.enabled = false
            config.traces.enabled = true
            _ = try OTel.bootstrap(configuration: config)
        }
        // We test the bootstrap API actually did bootstrap, by attempting a second bootstrap.
        await #expect(processExitsWith: .failure, "Running in a separate process because test uses bootstrap") {
            var config = OTel.Configuration.default
            config.logs.enabled = false
            config.metrics.enabled = false
            config.traces.enabled = true
            _ = try OTel.bootstrap(configuration: config)
            InstrumentationSystem.bootstrap(NoOpTracer())
        }
    }
}

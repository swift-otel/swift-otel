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

import NIOConcurrencyHelpers
@testable import OTel
import XCTest

final class OTelPeriodicExportingMetricsReaderConfigurationTests: XCTestCase {
    func test_exportInterval_withProgrammaticOverride_usesProgrammaticOverride() {
        let configuration = OTelPeriodicExportingMetricsReaderConfiguration(
            environment: OTelEnvironment(values: [:]),
            exportInterval: .seconds(42)
        )
        XCTAssertEqual(configuration.exportInterval, .seconds(42))
    }

    func test_exportInterval_withEnvironmentValue_usesEnvironmentValue() {
        let configuration = OTelPeriodicExportingMetricsReaderConfiguration(
            environment: OTelEnvironment(values: ["OTEL_METRIC_EXPORT_INTERVAL": "42000"]),
            exportInterval: nil
        )
        XCTAssertEqual(configuration.exportInterval, .seconds(42))
    }

    func test_exportInterval_withProgrammaticOverrideAndEnvironmentValue_usesProgrammaticOverride() {
        let configuration = OTelPeriodicExportingMetricsReaderConfiguration(
            environment: OTelEnvironment(values: ["OTEL_METRIC_EXPORT_INTERVAL": "42000"]),
            exportInterval: .seconds(84)
        )
        XCTAssertEqual(configuration.exportInterval, .seconds(84))
    }

    func test_exportInterval_withoutConfiguration_usesDefaultValue() {
        let configuration = OTelPeriodicExportingMetricsReaderConfiguration(
            environment: OTelEnvironment(values: [:])
        )
        XCTAssertEqual(configuration.exportInterval, .seconds(60))
    }

    func test_exportTimeout_withProgrammaticOverride_usesProgrammaticOverride() {
        let configuration = OTelPeriodicExportingMetricsReaderConfiguration(
            environment: OTelEnvironment(values: [:]),
            exportTimeout: .seconds(42)
        )
        XCTAssertEqual(configuration.exportTimeout, .seconds(42))
    }

    func test_exportTimeout_withEnvironmentValue_usesEnvironmentValue() {
        let configuration = OTelPeriodicExportingMetricsReaderConfiguration(
            environment: OTelEnvironment(values: ["OTEL_METRIC_EXPORT_TIMEOUT": "42000"]),
            exportTimeout: nil
        )
        XCTAssertEqual(configuration.exportTimeout, .seconds(42))
    }

    func test_exportTimeout_withProgrammaticOverrideAndEnvironmentValue_usesProgrammaticOverride() {
        let configuration = OTelPeriodicExportingMetricsReaderConfiguration(
            environment: OTelEnvironment(values: ["OTEL_METRIC_EXPORT_TIMEOUT": "42000"]),
            exportTimeout: .seconds(84)
        )
        XCTAssertEqual(configuration.exportTimeout, .seconds(84))
    }

    func test_exportTimeout_withoutConfiguration_usesDefaultValue() {
        let configuration = OTelPeriodicExportingMetricsReaderConfiguration(
            environment: OTelEnvironment(values: [:])
        )
        XCTAssertEqual(configuration.exportTimeout, .seconds(30))
    }
}

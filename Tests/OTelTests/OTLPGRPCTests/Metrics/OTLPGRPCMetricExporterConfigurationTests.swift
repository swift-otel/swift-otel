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

import NIOHPACK
@testable import OTel
@testable import OTLPGRPC
import XCTest

final class OTLPGRPCMetricExporterConfigurationTests: XCTestCase {
    func test_init_insecure_specificEnvironment_invalid_throwsConfigurationError() throws {
        do {
            let configuration = try OTLPGRPCMetricExporterConfiguration(
                environment: ["OTEL_EXPORTER_OTLP_METRICS_INSECURE": "not-a-bool"],
                endpoint: "test:1234"
            )
            XCTFail("Expected configuration error, got configuration: \(configuration)")
        } catch let error as OTelEnvironmentValueError {
            XCTAssertEqual(
                error,
                OTelEnvironmentValueError(
                    key: "OTEL_EXPORTER_OTLP_METRICS_INSECURE",
                    value: "not-a-bool",
                    valueType: Bool.self
                )
            )
        }
    }

    func test_init_insecure_commonEnvironment_invalid_throwsConfigurationError() throws {
        do {
            let configuration = try OTLPGRPCMetricExporterConfiguration(
                environment: ["OTEL_EXPORTER_OTLP_INSECURE": "not-a-bool"],
                endpoint: "test:1234"
            )
            XCTFail("Expected configuration error, got configuration: \(configuration)")
        } catch let error as OTelEnvironmentValueError {
            XCTAssertEqual(
                error,
                OTelEnvironmentValueError(
                    key: "OTEL_EXPORTER_OTLP_INSECURE",
                    value: "not-a-bool",
                    valueType: Bool.self
                )
            )
        }
    }

    func test_init_endpoint_programmatic_valid() throws {
        let configuration = try OTLPGRPCMetricExporterConfiguration(
            environment: [:],
            endpoint: "test:1234"
        )

        XCTAssertEqual(configuration.endpoint, OTLPGRPCEndpoint(host: "test", port: 1234, isInsecure: false))
    }

    func test_init_endpoint_programmatic_preferredOverEnvironmentValue() throws {
        let configuration = try OTLPGRPCMetricExporterConfiguration(
            environment: ["OTEL_EXPORTER_OTLP_METRICS_ENDPOINT": "environment:5678"],
            endpoint: "test:1234"
        )

        XCTAssertEqual(configuration.endpoint, OTLPGRPCEndpoint(host: "test", port: 1234, isInsecure: false))
    }

    func test_init_endpoint_programmatic_invalid_throwsConfigurationError() throws {
        do {
            let configuration = try OTLPGRPCMetricExporterConfiguration(
                environment: [:],
                endpoint: "host-without-port"
            )
            XCTFail("Expected configuration error, got configuration: \(configuration)")
        } catch let error as OTLPGRPCEndpointConfigurationError {
            XCTAssertEqual(error.value, "host-without-port")
        }
    }

    func test_init_endpoint_programatic_valid_withHTTPSScheme_overridesSpecificInsecureFlag() throws {
        let configuration = try OTLPGRPCMetricExporterConfiguration(
            environment: ["OTEL_EXPORTER_OTLP_METRICS_INSECURE": "true"],
            endpoint: "https://test:1234"
        )

        XCTAssertEqual(configuration.endpoint, OTLPGRPCEndpoint(host: "test", port: 1234, isInsecure: false))
    }

    func test_init_endpoint_programatic_valid_withHTTPScheme_overridesSpecificInsecureFlag() throws {
        let configuration = try OTLPGRPCMetricExporterConfiguration(
            environment: ["OTEL_EXPORTER_OTLP_METRICS_INSECURE": "false"],
            endpoint: "http://test:1234"
        )

        XCTAssertEqual(configuration.endpoint, OTLPGRPCEndpoint(host: "test", port: 1234, isInsecure: true))
    }

    func test_init_endpoint_specificEnvironment_valid() throws {
        let configuration = try OTLPGRPCMetricExporterConfiguration(environment: [
            "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT": "traces:1234",
            "OTEL_EXPORTER_OTLP_ENDPOINT": "common:1234",
        ])

        XCTAssertEqual(configuration.endpoint, OTLPGRPCEndpoint(host: "traces", port: 1234, isInsecure: false))
    }

    func test_init_endpoint_specificEnvironment_invalid_throwsEnvironmentValueError() throws {
        do {
            let configuration = try OTLPGRPCMetricExporterConfiguration(environment: [
                "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT": "host-without-port",
                "OTEL_EXPORTER_OTLP_ENDPOINT": "common:1234",
            ])
            XCTFail("Expected configuration error, got configuration: \(configuration)")
        } catch let error as OTelEnvironmentValueError {
            XCTAssertEqual(error.key, "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT")
            XCTAssertEqual(error.value, "host-without-port")
            XCTAssertEqual(
                error,
                OTelEnvironmentValueError(
                    key: "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT",
                    value: "host-without-port",
                    valueType: OTLPGRPCEndpoint.self
                )
            )
        }
    }

    func test_init_endpoint_commonEnvironment_valid() throws {
        let configuration = try OTLPGRPCMetricExporterConfiguration(environment: [
            "OTEL_EXPORTER_OTLP_ENDPOINT": "common:1234",
        ])

        XCTAssertEqual(configuration.endpoint, OTLPGRPCEndpoint(host: "common", port: 1234, isInsecure: false))
    }

    func test_init_endpoint_commonEnvironment_invalid_throwsEnvironmentValueError() throws {
        do {
            let configuration = try OTLPGRPCMetricExporterConfiguration(environment: [
                "OTEL_EXPORTER_OTLP_ENDPOINT": "host-without-port",
            ])
            XCTFail("Expected configuration error, got configuration: \(configuration)")
        } catch let error as OTelEnvironmentValueError {
            XCTAssertEqual(
                error,
                OTelEnvironmentValueError(
                    key: "OTEL_EXPORTER_OTLP_ENDPOINT",
                    value: "host-without-port",
                    valueType: OTLPGRPCEndpoint.self
                )
            )
        }
    }

    func test_init_endpoint_withoutConfiguration_usesDefaultEndpoint() throws {
        let configuration = try OTLPGRPCMetricExporterConfiguration(environment: [:])

        XCTAssertEqual(configuration.endpoint, .default)
    }

    // MARK: - headers

    func test_init_headers_programmatic() throws {
        let headers: HPACKHeaders = ["test": "42"]

        let configuration = try OTLPGRPCMetricExporterConfiguration(
            environment: [:],
            headers: headers
        )

        XCTAssertEqual(configuration.headers, headers)
    }

    func test_init_headers_programmatic_preferredOverEnvironmentValue() throws {
        let headers: HPACKHeaders = ["programmatic": "42"]

        let configuration = try OTLPGRPCMetricExporterConfiguration(
            environment: ["OTEL_EXPORTER_OTLP_METRICS_HEADERS": "environment=42"],
            headers: headers
        )

        XCTAssertEqual(configuration.headers, headers)
    }

    func test_init_headers_specificEnvironment_singleKeyValuePair() throws {
        let configuration = try OTLPGRPCMetricExporterConfiguration(
            environment: ["OTEL_EXPORTER_OTLP_METRICS_HEADERS": "test=42"]
        )

        XCTAssertEqual(configuration.headers, ["test": "42"])
    }

    func test_init_headers_specificEnvironment_multipleKeyValuePairs() throws {
        let configuration = try OTLPGRPCMetricExporterConfiguration(
            environment: ["OTEL_EXPORTER_OTLP_METRICS_HEADERS": "test1=42,test2=84"]
        )

        XCTAssertEqual(configuration.headers, ["test1": "42", "test2": "84"])
    }

    func test_init_headers_specificEnvironment_keepsDuplicateEntries() throws {
        let configuration = try OTLPGRPCMetricExporterConfiguration(
            environment: ["OTEL_EXPORTER_OTLP_METRICS_HEADERS": "test=42,test=84"]
        )

        XCTAssertEqual(configuration.headers, ["test": "42", "test": "84"])
    }

    func test_init_headers_specificEnvironment_stripsWhitespacesInKey() throws {
        let configuration = try OTLPGRPCMetricExporterConfiguration(
            environment: ["OTEL_EXPORTER_OTLP_METRICS_HEADERS": " test =42"]
        )

        XCTAssertEqual(configuration.headers, ["test": "42"])
    }

    func test_init_headers_specificEnvironment_stripsWhitespacesInValue() throws {
        let configuration = try OTLPGRPCMetricExporterConfiguration(
            environment: ["OTEL_EXPORTER_OTLP_METRICS_HEADERS": "test=   42  "]
        )

        XCTAssertEqual(configuration.headers, ["test": "42"])
    }
}

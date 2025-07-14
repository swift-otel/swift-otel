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

import OTelCore
import Testing

@Suite struct ConfigurationTests {
    // OTEL_SDK_DISABLED
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    @Test(.disabled("Not currently implemented")) func testSDKDisabled() {}

    // OTEL_LOG_LEVEL
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    @Test func testDiagnosticsLogLevel() {
        #expect(OTel.Configuration.default.diagnosticLogLevel.backing == .info)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_LOG_LEVEL": "trace",
        ]).diagnosticLogLevel.backing == .trace)
    }

    // OTEL_SERVICE_NAME
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/languages/sdk-configuration/general/#otel_service_name
    @Test func testServiceName() {
        #expect(OTel.Configuration.default.serviceName == "unknown_service")

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_SERVICE_NAME": "some_service",
        ]).serviceName == "some_service")

        withKnownIssue {
            Issue.record("""
            This property is a special since it's supposed to affect what ends up as the value for the service.name
            resource attribute during export.

            However, I don't think the right way to do that is to magically change the resource attributes of the confg
            object that the user has.

            Most likely this should be solved with a computed property on the config that's used by exporters, e.g.
            `resolvedResourceAttributes`.
            """)
        }

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_RESOURCE_ATTRIBUTES": "service.name=some_service_from_resource_attributes",
            "OTEL_SERVICE_NAME": "some_service_from_service_name",
        ]).serviceName == "some_service_from_service_name")
    }

    // OTEL_RESOURCE_ATTRIBUTES
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/languages/sdk-configuration/general/#otel_resource_attributes
    // https://opentelemetry.io/docs/specs/otel/resource/sdk/#specifying-resource-information-via-an-environment-variable
    @Test func testResourceAttributes() {
        #expect(OTel.Configuration.default.resourceAttributes.isEmpty)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_RESOURCE_ATTRIBUTES": "key1=value1,key2=value2",
        ]).resourceAttributes == ["key1": "value1", "key2": "value2"])

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_RESOURCE_ATTRIBUTES": "key=first_value,key=second_value",
        ]).resourceAttributes == ["key": "second_value"])

        // The resource attributes provided as an environment variable are a bit special. Most configuration values are
        // taken from the environment variable as-is, and completely override the configuration value, but for resource
        // attributes, the values from the environment variable are considered additional and should be merged into the
        // existing value.
        OTel.Configuration.default.with { config in
            config.resourceAttributes["code_key"] = "code_value"
            config.resourceAttributes["shared_key"] = "code_wins"
            #expect(config.applyingEnvironmentOverrides(environment: [
                "OTEL_RESOURCE_ATTRIBUTES": "env_key=env_value,shared_key=env_loses",
            ]).resourceAttributes == [
                "code_key": "code_value",
                "shared_key": "code_wins",
                "env_key": "env_value",
            ])
        }
    }

    // OTEL_TRACES_SAMPLER
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/languages/sdk-configuration/general/#otel_traces_sampler
    @Test(.disabled("Not currently implemented")) func testTracesSampler() {}

    // OTEL_TRACES_SAMPLER_ARG
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/languages/sdk-configuration/general/#otel_traces_sampler_arg
    @Test(.disabled("Not currently implemented")) func testTracesSamplerArg() {}

    // OTEL_PROPAGATORS
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/languages/sdk-configuration/general/#otel_propagators
    @Test func testPropagators() {
        #expect(OTel.Configuration.default.propagators.map(\.backing) == [.traceContext, .baggage])

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_PROPAGATORS": "b3,xray",
        ]).propagators.map(\.backing) == [.b3, .xray])

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_PROPAGATORS": "none",
        ]).propagators.map(\.backing) == [])
    }

    // OTEL_BSP_SCHEDULE_DELAY
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#duration
    @Test func testBatchSpanProcessorScheduleDelay() {
        #expect(OTel.Configuration.default.traces.batchSpanProcessor.scheduleDelay == .milliseconds(5000))

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_SCHEDULE_DELAY": "3000",
        ]).traces.batchSpanProcessor.scheduleDelay == .seconds(3))

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_SCHEDULE_DELAY": "0",
        ]).traces.batchSpanProcessor.scheduleDelay == .zero)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_SCHEDULE_DELAY": "-3000",
        ]).traces.batchSpanProcessor.scheduleDelay == OTel.Configuration.default.traces.batchSpanProcessor.scheduleDelay)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_SCHEDULE_DELAY": "invalid",
        ]).traces.batchSpanProcessor.scheduleDelay == OTel.Configuration.default.traces.batchSpanProcessor.scheduleDelay)
    }

    // OTEL_BSP_EXPORT_TIMEOUT
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#timeout
    @Test func testBatchSpanProcessorExportTimeout() {
        #expect(OTel.Configuration.default.traces.batchSpanProcessor.exportTimeout == .milliseconds(30000))

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_EXPORT_TIMEOUT": "3000",
        ]).traces.batchSpanProcessor.exportTimeout == .seconds(3))

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_EXPORT_TIMEOUT": "0",
        ]).traces.batchSpanProcessor.exportTimeout == .zero)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_EXPORT_TIMEOUT": "-3000",
        ]).traces.batchSpanProcessor.exportTimeout == OTel.Configuration.default.traces.batchSpanProcessor.exportTimeout)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_EXPORT_TIMEOUT": "invalid",
        ]).traces.batchSpanProcessor.exportTimeout == OTel.Configuration.default.traces.batchSpanProcessor.exportTimeout)
    }

    // OTEL_BSP_MAX_QUEUE_SIZE
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#integer
    @Test func testBatchSpanProcessorMaxQueueSize() {
        #expect(OTel.Configuration.default.traces.batchSpanProcessor.maxQueueSize == 2048)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_MAX_QUEUE_SIZE": "1024",
        ]).traces.batchSpanProcessor.maxQueueSize == 1024)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_MAX_QUEUE_SIZE": "0",
        ]).traces.batchSpanProcessor.maxQueueSize == 0)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_MAX_QUEUE_SIZE": "-100",
        ]).traces.batchSpanProcessor.maxQueueSize == OTel.Configuration.default.traces.batchSpanProcessor.maxQueueSize)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_MAX_QUEUE_SIZE": "invalid",
        ]).traces.batchSpanProcessor.maxQueueSize == OTel.Configuration.default.traces.batchSpanProcessor.maxQueueSize)
    }

    // OTEL_BSP_MAX_EXPORT_BATCH_SIZE
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#integer
    @Test func testBatchSpanProcessorMaxExportBatchSize() {
        #expect(OTel.Configuration.default.traces.batchSpanProcessor.maxExportBatchSize == 512)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_MAX_EXPORT_BATCH_SIZE": "256",
        ]).traces.batchSpanProcessor.maxExportBatchSize == 256)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_MAX_EXPORT_BATCH_SIZE": "0",
        ]).traces.batchSpanProcessor.maxExportBatchSize == 0)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_MAX_EXPORT_BATCH_SIZE": "-50",
        ]).traces.batchSpanProcessor.maxExportBatchSize == OTel.Configuration.default.traces.batchSpanProcessor.maxExportBatchSize)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BSP_MAX_EXPORT_BATCH_SIZE": "invalid",
        ]).traces.batchSpanProcessor.maxExportBatchSize == OTel.Configuration.default.traces.batchSpanProcessor.maxExportBatchSize)
    }

    // OTEL_METRIC_EXPORT_INTERVAL
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#duration
    @Test func testMetricExportInterval() {
        #expect(OTel.Configuration.default.metrics.exportInterval == .seconds(60))

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_METRIC_EXPORT_INTERVAL": "30000",
        ]).metrics.exportInterval == .seconds(30))

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_METRIC_EXPORT_INTERVAL": "0",
        ]).metrics.exportInterval == .zero)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_METRIC_EXPORT_INTERVAL": "-5000",
        ]).metrics.exportInterval == OTel.Configuration.default.metrics.exportInterval)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_METRIC_EXPORT_INTERVAL": "invalid",
        ]).metrics.exportInterval == OTel.Configuration.default.metrics.exportInterval)
    }

    // OTEL_METRIC_EXPORT_TIMEOUT
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#timeout
    @Test func testMetricExportTimeout() {
        #expect(OTel.Configuration.default.metrics.exportTimeout == .seconds(30))

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_METRIC_EXPORT_TIMEOUT": "15000",
        ]).metrics.exportTimeout == .seconds(15))

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_METRIC_EXPORT_TIMEOUT": "0",
        ]).metrics.exportTimeout == .zero)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_METRIC_EXPORT_TIMEOUT": "-3000",
        ]).metrics.exportTimeout == OTel.Configuration.default.metrics.exportTimeout)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_METRIC_EXPORT_TIMEOUT": "invalid",
        ]).metrics.exportTimeout == OTel.Configuration.default.metrics.exportTimeout)
    }

    // OTEL_BLRP_SCHEDULE_DELAY
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#duration
    @Test func testBatchLogRecordProcessorScheduleDelay() {
        #expect(OTel.Configuration.default.logs.batchLogRecordProcessor.scheduleDelay == .seconds(1))

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_SCHEDULE_DELAY": "2000",
        ]).logs.batchLogRecordProcessor.scheduleDelay == .seconds(2))

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_SCHEDULE_DELAY": "0",
        ]).logs.batchLogRecordProcessor.scheduleDelay == .zero)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_SCHEDULE_DELAY": "-1000",
        ]).logs.batchLogRecordProcessor.scheduleDelay == OTel.Configuration.default.logs.batchLogRecordProcessor.scheduleDelay)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_SCHEDULE_DELAY": "invalid",
        ]).logs.batchLogRecordProcessor.scheduleDelay == OTel.Configuration.default.logs.batchLogRecordProcessor.scheduleDelay)
    }

    // OTEL_BLRP_EXPORT_TIMEOUT
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#timeout
    @Test func testBatchLogRecordProcessorExportTimeout() {
        #expect(OTel.Configuration.default.logs.batchLogRecordProcessor.exportTimeout == .seconds(30))

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_EXPORT_TIMEOUT": "15000",
        ]).logs.batchLogRecordProcessor.exportTimeout == .seconds(15))

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_EXPORT_TIMEOUT": "0",
        ]).logs.batchLogRecordProcessor.exportTimeout == .zero)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_EXPORT_TIMEOUT": "-5000",
        ]).logs.batchLogRecordProcessor.exportTimeout == OTel.Configuration.default.logs.batchLogRecordProcessor.exportTimeout)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_EXPORT_TIMEOUT": "invalid",
        ]).logs.batchLogRecordProcessor.exportTimeout == OTel.Configuration.default.logs.batchLogRecordProcessor.exportTimeout)
    }

    // OTEL_BLRP_MAX_QUEUE_SIZE
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#integer
    @Test func testBatchLogRecordProcessorMaxQueueSize() {
        #expect(OTel.Configuration.default.logs.batchLogRecordProcessor.maxQueueSize == 2048)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_MAX_QUEUE_SIZE": "1024",
        ]).logs.batchLogRecordProcessor.maxQueueSize == 1024)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_MAX_QUEUE_SIZE": "0",
        ]).logs.batchLogRecordProcessor.maxQueueSize == 0)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_MAX_QUEUE_SIZE": "-100",
        ]).logs.batchLogRecordProcessor.maxQueueSize == OTel.Configuration.default.logs.batchLogRecordProcessor.maxQueueSize)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_MAX_QUEUE_SIZE": "invalid",
        ]).logs.batchLogRecordProcessor.maxQueueSize == OTel.Configuration.default.logs.batchLogRecordProcessor.maxQueueSize)
    }

    // OTEL_BLRP_MAX_EXPORT_BATCH_SIZE
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#integer
    @Test func testBatchLogRecordProcessorMaxExportBatchSize() {
        #expect(OTel.Configuration.default.logs.batchLogRecordProcessor.maxExportBatchSize == 512)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_MAX_EXPORT_BATCH_SIZE": "256",
        ]).logs.batchLogRecordProcessor.maxExportBatchSize == 256)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_MAX_EXPORT_BATCH_SIZE": "0",
        ]).logs.batchLogRecordProcessor.maxExportBatchSize == 0)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_MAX_EXPORT_BATCH_SIZE": "-50",
        ]).logs.batchLogRecordProcessor.maxExportBatchSize == OTel.Configuration.default.logs.batchLogRecordProcessor.maxExportBatchSize)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_BLRP_MAX_EXPORT_BATCH_SIZE": "invalid",
        ]).logs.batchLogRecordProcessor.maxExportBatchSize == OTel.Configuration.default.logs.batchLogRecordProcessor.maxExportBatchSize)
    }

    // OTEL_TRACES_EXPORTER
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/languages/sdk-configuration/general/#otel_traces_exporter
    @Test func testTracesExporter() {
        #expect(OTel.Configuration.default.traces.enabled == true)
        #expect(OTel.Configuration.default.traces.exporter.backing == .otlp)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_TRACES_EXPORTER": "none",
        ]).traces.enabled == false)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_TRACES_EXPORTER": "jaeger",
        ]).traces.exporter.backing == .jaeger)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_TRACES_EXPORTER": "zipkin",
        ]).traces.exporter.backing == .zipkin)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_TRACES_EXPORTER": "console",
        ]).traces.exporter.backing == .console)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_TRACES_EXPORTER": "otlp",
        ]).traces.exporter.backing == .otlp)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_TRACES_EXPORTER": "mumble",
        ]).traces.exporter.backing == .otlp)
    }

    // OTEL_METRICS_EXPORTER
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/languages/sdk-configuration/general/#otel_metrics_exporter
    @Test func testMetricsExporter() {
        #expect(OTel.Configuration.default.metrics.enabled == true)
        #expect(OTel.Configuration.default.metrics.exporter.backing == .otlp)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_METRICS_EXPORTER": "console",
        ]).metrics.exporter.backing == .console)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_METRICS_EXPORTER": "none",
        ]).metrics.enabled == false)
    }

    // OTEL_LOGS_EXPORTER
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/languages/sdk-configuration/general/#otel_logs_exporter
    @Test func testLogsExporter() {
        #expect(OTel.Configuration.default.logs.enabled == true)
        #expect(OTel.Configuration.default.logs.exporter.backing == .otlp)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_LOGS_EXPORTER": "console",
        ]).logs.exporter.backing == .console)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_LOGS_EXPORTER": "none",
        ]).logs.enabled == false)
    }

    // OTEL_EXPORTER_OTLP_ENDPOINT
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#configuration-options
    // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#endpoint-urls-for-otlphttp
    @Test func testOTLPExporterEndpoint() {
        withKnownIssue("""
        We currently have an issue with how we handle the HTTP endpoints.

        OTLP/gRPC endpoints should be left alone, which we handle fine.

        OTLP/HTTP endpoints should default to a URL wth signal-specific path (e.g. `/v1/logs`).

        Our logic to resolve these between the general and signal-specific environment variables is working fine (later
        part of the test covers that).

        The problem is in how we configure the defaults.

        Our configuration datamodel uses a per-sigal OTLP exporter config, which makes a pretty clear API for the user.
        However, we also provide a public `OTel.Configuration.OTLPExporterConfig.default` which is the problem, since
        the endpoint URL depends on the signal, i.e. the context where it's used.

        The likely solution to this is to remove the `.default` from the public API and use signal-specific defaults
        internally.
        """) {
            #expect(OTel.Configuration.OTLPExporterConfiguration.default.protocol == .httpProtobuf)
            #expect(OTel.Configuration.OTLPExporterConfiguration.default.endpoint == "http://localhost:4318")
            #expect(OTel.Configuration.default.logs.otlpExporter.protocol == .httpProtobuf)
            #expect(OTel.Configuration.default.logs.otlpExporter.endpoint == "http://localhost:4318/v1/logs")
            #expect(OTel.Configuration.default.metrics.otlpExporter.protocol == .httpProtobuf)
            #expect(OTel.Configuration.default.metrics.otlpExporter.endpoint == "http://localhost:4318/v1/metrics")
            #expect(OTel.Configuration.default.traces.otlpExporter.protocol == .httpProtobuf)
            #expect(OTel.Configuration.default.traces.otlpExporter.endpoint == "http://localhost:4318/v1/traces")
        }

        OTel.Configuration.default.with { config in
            config.traces.otlpExporter.protocol = .httpProtobuf

            // Applies signal-specific suffix.
            config.withEnvironmentOverrides(environment: [
                "OTEL_EXPORTER_OTLP_ENDPOINT": "https://otel-collector.example.com:4318",
            ]) { config in
                #expect(config.logs.otlpExporter.endpoint == "https://otel-collector.example.com:4318/v1/logs")
                #expect(config.metrics.otlpExporter.endpoint == "https://otel-collector.example.com:4318/v1/metrics")
                #expect(config.traces.otlpExporter.endpoint == "https://otel-collector.example.com:4318/v1/traces")
            }

            // Handles trailing slash.
            config.withEnvironmentOverrides(environment: [
                "OTEL_EXPORTER_OTLP_ENDPOINT": "https://otel-collector.example.com:4318/",
            ]) { config in
                #expect(config.logs.otlpExporter.endpoint == "https://otel-collector.example.com:4318/v1/logs")
                #expect(config.metrics.otlpExporter.endpoint == "https://otel-collector.example.com:4318/v1/metrics")
                #expect(config.traces.otlpExporter.endpoint == "https://otel-collector.example.com:4318/v1/traces")
            }

            // Signal-specific endpoints takes precedence.
            config.withEnvironmentOverrides(environment: [
                "OTEL_EXPORTER_OTLP_ENDPOINT": "https://otel-collector.example.com:4318",
                "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT": "https://other-otel-collector.example.com:3123/custom",
            ]) { config in
                #expect(config.logs.otlpExporter.endpoint == "https://otel-collector.example.com:4318/v1/logs")
                #expect(config.metrics.otlpExporter.endpoint == "https://other-otel-collector.example.com:3123/custom")
                #expect(config.traces.otlpExporter.endpoint == "https://otel-collector.example.com:4318/v1/traces")
            }
        }

        OTel.Configuration.default.with { config in
            config.logs.otlpExporter.protocol = .grpc
            config.metrics.otlpExporter.protocol = .grpc
            config.traces.otlpExporter.protocol = .grpc

            // Applies signal-specific suffix.
            config.withEnvironmentOverrides(environment: [
                "OTEL_EXPORTER_OTLP_ENDPOINT": "https://otel-collector.example.com:4317",
            ]) { config in
                #expect(config.logs.otlpExporter.endpoint == "https://otel-collector.example.com:4317")
                #expect(config.metrics.otlpExporter.endpoint == "https://otel-collector.example.com:4317")
                #expect(config.traces.otlpExporter.endpoint == "https://otel-collector.example.com:4317")
            }

            // Trailing slash is untouched for gRPC endpoints.
            config.withEnvironmentOverrides(environment: [
                "OTEL_EXPORTER_OTLP_ENDPOINT": "https://otel-collector.example.com:4317/",
            ]) { config in
                #expect(config.logs.otlpExporter.endpoint == "https://otel-collector.example.com:4317/")
                #expect(config.metrics.otlpExporter.endpoint == "https://otel-collector.example.com:4317/")
                #expect(config.traces.otlpExporter.endpoint == "https://otel-collector.example.com:4317/")
            }

            // Signal-specific endpoints takes precedence.
            config.withEnvironmentOverrides(environment: [
                "OTEL_EXPORTER_OTLP_ENDPOINT": "https://otel-collector.example.com:4317",
                "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT": "https://other-otel-collector.example.com:3123/custom",
            ]) { config in
                #expect(config.logs.otlpExporter.endpoint == "https://otel-collector.example.com:4317")
                #expect(config.metrics.otlpExporter.endpoint == "https://other-otel-collector.example.com:3123/custom")
                #expect(config.traces.otlpExporter.endpoint == "https://otel-collector.example.com:4317")
            }
        }
    }

    // OTEL_EXPORTER_OTLP_HEADERS
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#configuration-options
    // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#specifying-headers-via-environment-variables
    @Test func testOTLPExporterHeaders() {
        #expect(OTel.Configuration.OTLPExporterConfiguration.default.headers.isEmpty)

        OTel.Configuration.default.withEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_HEADERS": "key1=value1,key2=value2 , key 3 = value 3 ",
        ]) { config in
            #expect(config.traces.otlpExporter.headers.count == 3)
            #expect(config.traces.otlpExporter.headers.contains { key, value in key == "key1" && value == "value1" })
            #expect(config.traces.otlpExporter.headers.contains { key, value in key == "key2" && value == "value2" })
            #expect(config.traces.otlpExporter.headers.contains { key, value in key == "key 3" && value == "value 3" })
        }

        // Signal-specific headers take precedence
        OTel.Configuration.default.withEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_HEADERS": "key=general",
            "OTEL_EXPORTER_OTLP_TRACES_HEADERS": "key=specific",
        ]) { config in
            #expect(config.logs.otlpExporter.headers.count == 1)
            #expect(config.logs.otlpExporter.headers.contains { key, value in key == "key" && value == "general" })
            #expect(config.metrics.otlpExporter.headers.count == 1)
            #expect(config.metrics.otlpExporter.headers.contains { key, value in key == "key" && value == "general" })
            #expect(config.traces.otlpExporter.headers.count == 1)
            #expect(config.traces.otlpExporter.headers.contains { key, value in key == "key" && value == "specific" })
        }
    }

    // OTEL_EXPORTER_OTLP_TIMEOUT
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#timeout
    // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#configuration-options
    @Test func testOTLPExporterTimeout() {
        #expect(OTel.Configuration.OTLPExporterConfiguration.default.timeout == .seconds(10))

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_TIMEOUT": "5000",
        ]).traces.otlpExporter.timeout == .seconds(5))

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_TIMEOUT": "0",
        ]).traces.otlpExporter.timeout == .zero)

        // Negative values should be ignored
        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_TIMEOUT": "-1000",
        ]).traces.otlpExporter.timeout == OTel.Configuration.default.traces.otlpExporter.timeout)

        // Invalid values should be ignored
        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_TIMEOUT": "invalid",
        ]).traces.otlpExporter.timeout == OTel.Configuration.default.traces.otlpExporter.timeout)

        // Signal-specific key
        OTel.Configuration.default.withEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_TIMEOUT": "5000",
            "OTEL_EXPORTER_OTLP_TRACES_TIMEOUT": "3000",
        ]) { config in
            #expect(config.logs.otlpExporter.timeout == .seconds(5))
            #expect(config.metrics.otlpExporter.timeout == .seconds(5))
            #expect(config.traces.otlpExporter.timeout == .seconds(3))
        }
    }

    // OTEL_EXPORTER_OTLP_PROTOCOL
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#configuration-options
    @Test func testOTLPExporterProtocol() {
        #expect(OTel.Configuration.OTLPExporterConfiguration.default.protocol == .httpProtobuf)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_PROTOCOL": "http/json",
        ]).traces.otlpExporter.protocol.backing == .httpJSON)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
        ]).traces.otlpExporter.protocol.backing == .grpc)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
        ]).traces.otlpExporter.protocol.backing == .httpProtobuf)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_PROTOCOL": "invalid",
        ]).traces.otlpExporter.protocol.backing == .httpProtobuf)

        OTel.Configuration.default.withEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_PROTOCOL": "http/json",
            "OTEL_EXPORTER_OTLP_TRACES_PROTOCOL": "grpc",
        ]) { config in
            #expect(config.logs.otlpExporter.protocol == .httpJSON)
            #expect(config.metrics.otlpExporter.protocol == .httpJSON)
            #expect(config.traces.otlpExporter.protocol == .grpc)
        }
    }

    // OTEL_EXPORTER_OTLP_COMPRESSION
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#configuration-options
    @Test func testOTLPExporterCompression() {
        #expect(OTel.Configuration.OTLPExporterConfiguration.default.compression.backing == .none)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_COMPRESSION": "gzip",
        ]).traces.otlpExporter.compression.backing == .gzip)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_COMPRESSION": "none",
        ]).traces.otlpExporter.compression.backing == .none)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_COMPRESSION": "invalid",
        ]).traces.otlpExporter.compression.backing == .none)

        OTel.Configuration.default.withEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_COMPRESSION": "gzip",
            "OTEL_EXPORTER_OTLP_TRACES_COMPRESSION": "none",
        ]) { config in
            #expect(config.logs.otlpExporter.compression.backing == .gzip)
            #expect(config.metrics.otlpExporter.compression.backing == .gzip)
            #expect(config.traces.otlpExporter.compression.backing == .none)
        }
    }

    // OTEL_EXPORTER_OTLP_INSECURE
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#boolean
    // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#configuration-options
    @Test func testOTLPExporterInsecure() {
        // TODO: this should be the default check for each of the tests
        #expect(OTel.Configuration.OTLPExporterConfiguration.default.insecure == false)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_INSECURE": "true",
        ]).traces.otlpExporter.insecure == true)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_INSECURE": "TRUE",
        ]).traces.otlpExporter.insecure == true)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_INSECURE": "false",
        ]).traces.otlpExporter.insecure == false)

        // The OTel spec says only case-insensitive "true" should be true, everything else is false.
        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_INSECURE": "ON",
        ]).traces.otlpExporter.insecure == false)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_INSECURE": "YES",
        ]).traces.otlpExporter.insecure == false)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_INSECURE": "invalid",
        ]).traces.otlpExporter.insecure == false)

        OTel.Configuration.default.withEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_INSECURE": "true",
            "OTEL_EXPORTER_OTLP_TRACES_INSECURE": "false",
        ]) { config in
            #expect(config.logs.otlpExporter.insecure == true)
            #expect(config.metrics.otlpExporter.insecure == true)
            #expect(config.traces.otlpExporter.insecure == false)
        }
    }

    // OTEL_EXPORTER_OTLP_CERTIFICATE
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#configuration-options
    @Test func testOTLPExporterCertificate() {
        #expect(OTel.Configuration.default.traces.otlpExporter.certificateFilePath == nil)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_CERTIFICATE": "/path/to/cert.pem",
        ]).traces.otlpExporter.certificateFilePath == "/path/to/cert.pem")

        OTel.Configuration.default.withEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_CERTIFICATE": "/path/to/general.pem",
            "OTEL_EXPORTER_OTLP_TRACES_CERTIFICATE": "/path/to/traces.pem",
        ]) { config in
            #expect(config.logs.otlpExporter.certificateFilePath == "/path/to/general.pem")
            #expect(config.metrics.otlpExporter.certificateFilePath == "/path/to/general.pem")
            #expect(config.traces.otlpExporter.certificateFilePath == "/path/to/traces.pem")
        }
    }

    // OTEL_EXPORTER_OTLP_CLIENT_KEY
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#configuration-options
    @Test func testOTLPExporterClientKey() {
        #expect(OTel.Configuration.default.traces.otlpExporter.clientKeyFilePath == nil)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_CLIENT_KEY": "/path/to/client.key",
        ]).traces.otlpExporter.clientKeyFilePath == "/path/to/client.key")

        OTel.Configuration.default.withEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_CLIENT_KEY": "/path/to/general.key",
            "OTEL_EXPORTER_OTLP_TRACES_CLIENT_KEY": "/path/to/traces.key",
        ]) { config in
            #expect(config.logs.otlpExporter.clientKeyFilePath == "/path/to/general.key")
            #expect(config.metrics.otlpExporter.clientKeyFilePath == "/path/to/general.key")
            #expect(config.traces.otlpExporter.clientKeyFilePath == "/path/to/traces.key")
        }
    }

    // OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE
    // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#configuration-options
    @Test func testOTLPExporterClientCertificate() {
        #expect(OTel.Configuration.default.traces.otlpExporter.clientCertificateFilePath == nil)

        #expect(OTel.Configuration.default.applyingEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE": "/path/to/client.crt",
        ]).traces.otlpExporter.clientCertificateFilePath == "/path/to/client.crt")

        OTel.Configuration.default.withEnvironmentOverrides(environment: [
            "OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE": "/path/to/general.crt",
            "OTEL_EXPORTER_OTLP_TRACES_CLIENT_CERTIFICATE": "/path/to/traces.crt",
        ]) { config in
            #expect(config.logs.otlpExporter.clientCertificateFilePath == "/path/to/general.crt")
            #expect(config.metrics.otlpExporter.clientCertificateFilePath == "/path/to/general.crt")
            #expect(config.traces.otlpExporter.clientCertificateFilePath == "/path/to/traces.crt")
        }
    }
}

extension OTel.Configuration {
    fileprivate func applyingEnvironmentOverrides(environment: [String: String]) -> Self {
        var result = self
        result.applyEnvironmentOverrides(environment: environment)
        return result
    }

    fileprivate func withEnvironmentOverrides<Result>(environment: [String: String], operation: (Self) throws -> Result) rethrows -> Result {
        try operation(applyingEnvironmentOverrides(environment: environment))
    }

    fileprivate func with<Result>(operation: (inout Self) throws -> Result) rethrows -> Result {
        var config = self
        return try (operation(&config))
    }
}

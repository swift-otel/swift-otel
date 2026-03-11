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

import Logging

protocol OTelEnvironmentVariableRepresentable {
    init?(environmentVariableValue: String)
    var environmentVariableValue: String { get }
    static var hint: String? { get }
}

extension OTelEnvironmentVariableRepresentable {
    static var hint: String? { nil }
}

extension OTelEnvironmentVariableRepresentable {
    fileprivate mutating func override(
        using key: OTel.Configuration.Key,
        from environment: [String: String],
        logger: Logger? = nil
    ) {
        guard let proposedValue = environment.getStringValue(key) else { return }

        let result: OTelEnvironmentOverrideResult
        let previousValue = self

        if let newValue = Self(environmentVariableValue: proposedValue) {
            self = newValue
            result = .success
        } else {
            result = .failure(hint: Self.hint)
        }

        logger?.logOverride(
            environmentKey: key.environmentVariableName,
            environmentValue: proposedValue,
            previousValue: previousValue.environmentVariableValue,
            newValue: environmentVariableValue,
            result: result
        )
    }

    internal mutating func override(
        using key: OTel.Configuration.Key.GeneralKey,
        from environment: [String: String],
        logger: Logger? = nil
    ) {
        override(using: .single(key), from: environment, logger: logger)
    }

    internal mutating func override(
        using key: OTel.Configuration.Key.SignalSpecificKey,
        for signal: OTel.Configuration.Key.Signal,
        from environment: [String: String],
        logger: Logger? = nil
    ) {
        override(using: .signalSpecific(key, signal), from: environment, logger: logger)
    }
}

private enum OTelEnvironmentOverrideResult {
    case success
    case failure(hint: String?)
}

extension Logger {
    fileprivate func logOverride(
        environmentKey: String,
        environmentValue: String,
        previousValue: String,
        newValue: String,
        result: OTelEnvironmentOverrideResult
    ) {
        var logger = self

        logger[metadataKey: "environment_key"] = "\(environmentKey)"
        logger[metadataKey: "environment_value"] = "\(environmentValue)"
        logger[metadataKey: "previous_value"] = "\(previousValue)"
        logger[metadataKey: "new_value"] = "\(newValue)"

        switch result {
        case .success:
            logger.info("Configuration updated from environment")
        case .failure(let hint):
            if let hint { logger[metadataKey: "hint"] = "\(hint)" }
            logger.warning("Failed to update configuration from environment")
        }
    }
}

extension Bool: OTelEnvironmentVariableRepresentable {
    init?(environmentVariableValue: String) {
        // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#boolean
        switch environmentVariableValue.lowercased() {
        case "true": self = true
        case "false", "": self = false
        default: return nil
        }
    }

    var environmentVariableValue: String { self ? "true" : "false" }

    static var hint: String? { "Value must be case-insensitive string `true`, `false`, or empty" }
}

extension Int: OTelEnvironmentVariableRepresentable {
    init?(environmentVariableValue: String) {
        // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#integer
        guard let value = Int(environmentVariableValue), value >= 0 else { return nil }
        self = value
    }

    var environmentVariableValue: String { "\(self)" }

    static var hint: String? { "Value must be a non-negative integer" }
}

extension Double: OTelEnvironmentVariableRepresentable {
    init?(environmentVariableValue: String) {
        guard let value = Double(environmentVariableValue) else { return nil }
        self = value
    }

    var environmentVariableValue: String { "\(self)" }

    static var hint: String? { "Value must be a double" }
}

extension Duration: OTelEnvironmentVariableRepresentable {
    init?(environmentVariableValue: String) {
        // https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#duration
        guard let value = Int(environmentVariableValue), value >= 0 else { return nil }
        self = .milliseconds(value)
    }

    var environmentVariableValue: String {
        String(components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000)
    }

    static var hint: String? { "Value must be a non-negative integer number of milliseconds" }
}

extension String: OTelEnvironmentVariableRepresentable {
    init?(environmentVariableValue: String) { self = environmentVariableValue }
    var environmentVariableValue: String { self }
}

extension RawRepresentable where RawValue == String {
    init?(environmentVariableValue: String) { self.init(rawValue: environmentVariableValue) }
    var environmentVariableValue: String { rawValue }
}

extension CaseIterable where AllCases.Element: RawRepresentable, AllCases.Element.RawValue == String {
    static var supportedEnvironmentVariableValues: [String] { Self.allCases.map(\.rawValue) }
}

protocol OTelEnum<Backing>: OTelEnvironmentVariableRepresentable
where Backing: RawRepresentable<String> & CaseIterable {
    associatedtype Backing
    var backing: Backing { get }
    init(backing: Backing)
}

extension OTelEnum {
    init?(environmentVariableValue: String) {
        guard let backing = Backing(environmentVariableValue: environmentVariableValue) else { return nil }
        self.init(backing: backing)
    }

    var environmentVariableValue: String { backing.environmentVariableValue }
    static var supportedEnvironmentVariableValues: [String] { Backing.supportedEnvironmentVariableValues }
    static var hint: String? { "Value must be one of: \(Backing.supportedEnvironmentVariableValues)" }
}

extension Array: OTelEnvironmentVariableRepresentable where Element: OTelEnvironmentVariableRepresentable {
    init?(environmentVariableValue: String) {
        /// The OTel spec is pretty clear about how to handle unsupported values: the SDK should log and fallback to the
        /// default.
        ///
        /// However, it's not clear on how an SDK should behave when only some of the values in a comma-separated list
        /// are unsupported.
        ///
        /// There are a few options:
        /// 1. Just use the valid values, and warn and skip the invalid ones.
        /// 2. If any are invalid, warn and abort the override.
        ///
        /// This implementation goes for (2) since if an adopter has chosen a list, we cannot decide that a partial
        /// override is acceptable for them. And, in the cases where they provide only invalid values, allowing this
        /// to proceed with an empty list may be very harmful. For example, a typo in the sampler configuration should
        /// not result in no sampling, since the adopter presumably wants sampling, and it's possible that disabling
        /// sampling altogether will have a negative performance implication.
        var newValues: [Element] = []
        for proposedValue in environmentVariableValue.split(separator: ",") {
            guard let value = Element(environmentVariableValue: String(proposedValue)) else { return nil }
            newValues.append(value)
        }
        self = newValues
    }

    var environmentVariableValue: String {
        map(\.environmentVariableValue).joined(separator: ",")
    }

    static var hint: String? {
        guard let elementHint = Element.hint else { return nil }
        return "Value must be a comma-separated list of values where, for each value: \(elementHint)"
    }
}

extension Optional: OTelEnvironmentVariableRepresentable where Wrapped: OTelEnvironmentVariableRepresentable {
    init?(environmentVariableValue: String) {
        guard let value = Wrapped(environmentVariableValue: environmentVariableValue) else { return nil }
        self = .some(value)
    }

    var environmentVariableValue: String {
        switch self {
        case .some(let value): value.environmentVariableValue
        case .none: "none"
        }
    }
}

extension OTel.Configuration.Propagator: OTelEnum {}
extension OTel.Configuration.LogLevel: OTelEnum {}
extension OTel.Configuration.LogsConfiguration.ExporterSelection: OTelEnum {}
extension OTel.Configuration.MetricsConfiguration.ExporterSelection: OTelEnum {}
extension OTel.Configuration.TracesConfiguration.ExporterSelection: OTelEnum {}
extension OTel.Configuration.OTLPExporterConfiguration.Compression: OTelEnum {}
// swiftformat:disable:next redundantBackticks
extension OTel.Configuration.OTLPExporterConfiguration.`Protocol`: OTelEnum {}
extension OTel.Configuration.TracesConfiguration.SamplerConfiguration.Backing: OTelEnvironmentVariableRepresentable {}

extension OTel.Configuration.TracesConfiguration.SamplerConfiguration.ArgumentBacking? {
    internal mutating func override(
        for sampler: OTel.Configuration.TracesConfiguration.SamplerConfiguration.Backing,
        using key: OTel.Configuration.Key.GeneralKey,
        from environment: [String: String],
        logger: Logger? = nil
    ) {
        if let proposedValue = environment.getStringValue(key) {
            let result: OTelEnvironmentOverrideResult
            let previousValue = self

            switch sampler {
            case .traceIDRatio, .parentBasedTraceIDRatio:
                guard let value = Double(proposedValue), value >= 0.0, value <= 1.0 else {
                    result = .failure(
                        hint: "Value must be a sampling probability: a number in the [0..1] range, e.g. `0.25`"
                    )
                    break
                }
                self = .traceIDRatio(samplingProbability: value)
                result = .success
            case .jaegerRemote, .parentBasedJaegerRemote:
                // Example: endpoint=http://localhost:14250,pollingIntervalMs=5000,initialSamplingRate=0.25
                let parameters = proposedValue.split(separator: ",", maxSplits: 3).map {
                    $0.split(separator: "=", maxSplits: 2)
                }
                guard
                    parameters.count == 3, parameters.allSatisfy({ $0.count == 2 }),
                    parameters[0][0] == "endpoint",
                    let endpoint = String(parameters[0][1]) as String?,
                    parameters[1][0] == "pollingIntervalMs",
                    let pollingIntervalMilliseconds = Int(parameters[1][1]),
                    parameters[2][0] == "initialSamplingRate",
                    let initialSamplingRate = Double(parameters[2][1])
                else {
                    result = .failure(
                        hint:
                            "Value must be a comma-separated list of key-value pairs in a specific order. Example: `endpoint=http://localhost:14250,pollingIntervalMs=5000,initialSamplingRate=0.25`"
                    )
                    break
                }
                self = .jaegerRemote(
                    endpoint: endpoint,
                    pollingInterval: .milliseconds(pollingIntervalMilliseconds),
                    initialSamplingRate: initialSamplingRate
                )
                result = .success
            default:
                result = .failure(hint: "Argument is not supported for \(sampler) sampler")
            }

            logger?.logOverride(
                environmentKey: key.key,
                environmentValue: proposedValue,
                previousValue: previousValue.environmentVariableValue,
                newValue: environmentVariableValue,
                result: result
            )
        }
    }

    var environmentVariableValue: String {
        switch self {
        case .traceIDRatio(let samplingProbability):
            "\(samplingProbability)"
        case .jaegerRemote(let endpoint, let pollingInterval, let initialSamplingRate):
            "endpoint=\(endpoint),pollingIntervalMs=\(pollingInterval),initialSamplingRate=\(initialSamplingRate)"
        case .none: "none"
        }
    }
}

struct OTelHeaders {
    var backing: [(String, String)]
}

extension OTelHeaders: OTelEnvironmentVariableRepresentable {
    init?(environmentVariableValue: String) {
        // https://opentelemetry.io/docs/specs/otel/protocol/exporter/#specifying-headers-via-environment-variables
        var backing: [(String, String)] = []
        for header in environmentVariableValue.utf8.split(separator: .init(ascii: ",")) {
            let pair = header.split(separator: .init(ascii: "="), maxSplits: 1, omittingEmptySubsequences: true)
            guard let key = pair.first, let value = pair.dropFirst().first else { return nil }
            backing.append(
                (
                    String(decoding: key, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines),
                    String(decoding: value, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }
        self.backing = backing
    }

    var environmentVariableValue: String {
        backing.map { key, value in "\(key)=\(value)" }.joined(separator: ",")
    }
}

struct OTelResourceAttributes {
    var backing: [String: String]
}

extension OTelResourceAttributes: OTelEnvironmentVariableRepresentable {
    init?(environmentVariableValue: String) {
        // https://opentelemetry.io/docs/specs/otel/resource/sdk/#specifying-resource-information-via-an-environment-variable
        guard let resourceAttributes = OTelHeaders(environmentVariableValue: environmentVariableValue) else {
            return nil
        }
        backing = Dictionary(resourceAttributes.backing, uniquingKeysWith: { _, second in second })
    }

    var environmentVariableValue: String {
        backing.map { key, value in "\(key)=\(value)" }.joined(separator: ",")
    }

    internal mutating func merge(
        using key: OTel.Configuration.Key.GeneralKey,
        from environment: [String: String],
        logger: Logger? = nil
    ) {
        guard let proposedValue = environment[key.key] else { return }
        let previousValue = self
        let result: OTelEnvironmentOverrideResult
        if let resourceAttributes = OTelHeaders(environmentVariableValue: proposedValue) {
            let incomingAttributes = Dictionary(resourceAttributes.backing, uniquingKeysWith: { _, second in second })
            backing.merge(incomingAttributes, uniquingKeysWith: { current, _ in current })
            result = .success
        } else {
            result = .failure(hint: "Value must be comma-separated key=value pairs")
        }

        logger?.logOverride(
            environmentKey: key.key,
            environmentValue: proposedValue,
            previousValue: previousValue.environmentVariableValue,
            newValue: environmentVariableValue,
            result: result
        )
    }
}

extension [(String, String)] {
    internal mutating func override(
        using key: OTel.Configuration.Key.SignalSpecificKey,
        for signal: OTel.Configuration.Key.Signal,
        from environment: [String: String],
        logger: Logger? = nil
    ) {
        var headers = OTelHeaders(backing: self)
        headers.override(using: .otlpExporterHeaders, for: signal, from: environment, logger: logger)
        self = headers.backing
    }
}

extension [String: String] {
    internal mutating func merge(
        using key: OTel.Configuration.Key.GeneralKey,
        from environment: [String: String],
        logger: Logger? = nil
    ) {
        var resourceAttributes = OTelResourceAttributes(backing: self)
        resourceAttributes.merge(using: key, from: environment, logger: logger)
        self = resourceAttributes.backing
    }
}

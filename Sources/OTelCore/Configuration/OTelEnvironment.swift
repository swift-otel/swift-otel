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

#if canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#else
    import Darwin.C
#endif

import Foundation

/// A wrapper for reading environment values.
public struct OTelEnvironment: Sendable {
    /// The key-value pairs in the environment.
    ///
    /// - Note: All keys are lowercased to enable case-insensitive lookup.
    public let values: [String: String]

    /// Create an environment wrapping the given key-value pairs.
    ///
    /// - Parameter values: The key-value pairs to wrap.
    public init(values: [String: String]) {
        self.values = Dictionary(uniqueKeysWithValues: values.map { ($0.key.lowercased(), $0.value) })
    }

    /// Accesses the value associated with the given key for reading by ignoring its case.
    ///
    /// - Parameter key: The key to look up case-insensitively.
    public subscript(key: String) -> String? {
        values[key.lowercased()]
    }

    /// Retrieve a configuration value by transforming an environment value into the given type.
    ///
    /// ## Configuration Precedence
    ///
    /// When retrieving a configuration value, the following precedence applies:
    /// 1. `programmaticOverride`, unless it's `nil`
    /// 2. `key`, if an environment value is present
    ///
    /// - Parameters:
    ///   - programmaticOverride: A value overriding the environment value.
    ///   - key: The environment key for the configuration value.
    ///   - defaultValue: A fallback value used if the value is not configured.
    ///   - transformValue: A closure transforming an environment value into the given type.
    /// - Warning: This method crashes if transforming the environment value fails.
    /// - Returns: The configuration value with the highest specificity.
    public func requiredValue<T>(
        programmaticOverride: T?,
        key: String,
        defaultValue: T,
        transformValue: (_ value: String) -> T?
    ) -> T {
        do {
            let value = try value(
                programmaticOverride: programmaticOverride,
                key: key,
                transformValue: transformValue
            )
            return value ?? defaultValue
        } catch {
            fatalError("\(error)")
        }
    }

    /// Retrieve a configuration value by transforming an environment value into the given type.
    ///
    /// ## Configuration Precedence
    ///
    /// When retrieving a configuration value, the following precedence applies:
    /// 1. `programmaticOverride`, unless it's `nil`
    /// 2. `key`, if an environment value is present
    ///
    /// - Parameters:
    ///   - programmaticOverride: A value overriding the environment value.
    ///   - key: The environment key for the configuration value.
    ///   - transformValue: A closure transforming an environment value into the given type.
    /// - Returns: The configuration value with the highest specificity, or `nil` if the value was not configured.
    /// - Throws: ``OTelEnvironmentValueError`` if an environment value could not be transformed into the given type.
    public func value<T>(
        programmaticOverride: T?,
        key: String,
        transformValue: (_ value: String) -> T?
    ) throws -> T? {
        if let programmaticOverride {
            return programmaticOverride
        }

        if let value = self[key] {
            return try transformedValue(value, forKey: key, using: transformValue)
        }

        return nil
    }

    /// Retrieve a configuration value by transforming an appropriate environment value into the given type.
    ///
    /// ## Value Precedence
    ///
    /// When retrieving a configuration value the following precedence applies:
    /// 1. `programmaticOverride`, unless it's `nil`
    /// 2. `signalSpecificKey`, if an environment value is present
    /// 3. `sharedKey`, if an environment value is present
    ///
    /// - Parameters:
    ///   - programmaticOverride: A value overriding any environment value.
    ///   - signalSpecificKey: The environment key for the signal-specific configuration value.
    ///   - sharedKey: The environment key for the configuration value shared amongst all signals.
    ///   - transformValue: A closure transforming an environment value into the given type.
    ///
    /// - Returns: The configuration value with the highest specificity, or `nil` if the value was not configured.
    /// - Throws: ``OTelEnvironmentValueError`` is an environment value could not be transformed into the given type.
    public func value<T>(
        programmaticOverride: T?,
        signalSpecificKey: String,
        sharedKey: String,
        transformValue: (_ value: String) -> T?
    ) throws -> T? {
        if let programmaticOverride {
            return programmaticOverride
        }

        if let value = self[signalSpecificKey] {
            return try transformedValue(value, forKey: signalSpecificKey, using: transformValue)
        } else if let value = self[sharedKey] {
            return try transformedValue(value, forKey: sharedKey, using: transformValue)
        }

        return nil
    }

    /// Retrieve a boolean by transforming an appropriate environment value.
    ///
    /// - Parameters:
    ///   - programmaticOverride: A value overriding any environment value.
    ///   - signalSpecificKey: The environment key for the signal-specific configuration value.
    ///   - sharedKey: The environment key for the configuration value shared amongst all signals.
    ///
    /// - Returns: The configuration value with the highest specificity, or `nil` if the value was not configured.
    /// - Throws: ``OTelEnvironmentValueError`` is an environment value could not be transformed into the given type.
    public func value(
        programmaticOverride: Bool?,
        signalSpecificKey: String,
        sharedKey: String
    ) throws -> Bool? {
        try value(
            programmaticOverride: programmaticOverride,
            signalSpecificKey: signalSpecificKey,
            sharedKey: sharedKey,
            transformValue: { value in
                if value.lowercased() == "true" {
                    return true
                } else if value.lowercased() == "false" {
                    return false
                } else {
                    return nil
                }
            }
        )
    }

    /// An ``OTelEnvironment`` exposing the process-wide environment values.
    ///
    /// - Returns: An ``OTelEnvironment`` exposing the process-wide environment values.
    public static func detected() -> OTelEnvironment {
        let values = ProcessInfo.processInfo.environment
        return OTelEnvironment(values: Dictionary(uniqueKeysWithValues: values.map { ($0.key.lowercased(), $0.value) }))
    }

    /// Extract headers from a given environment value.
    ///
    /// - Parameter value: The value containing a comma-separated list of headers.
    /// - Returns: The extracted headers as an array of key-value pairs, or nil if parsing fails.
    public static func headers(parsingValue value: String) -> [(key: String, value: String)]? {
        var headers = [(key: String, value: String)]()

        let keyValuePairs = value.split(separator: ",")
        for keyValuePair in keyValuePairs {
            guard let valueSeparatorIndex = keyValuePair.firstIndex(of: "=") else {
                return nil
            }
            let key = keyValuePair
                .prefix(upTo: valueSeparatorIndex)
                .trimmingCharacters(in: .whitespaces)
            let value = keyValuePair[keyValuePair.index(after: valueSeparatorIndex)...]
                .trimmingCharacters(in: .whitespaces)
            headers.append((key, value))
        }

        return headers
    }

    private func transformedValue<T>(
        _ value: String,
        forKey key: String,
        using transform: (String) -> T?
    ) throws -> T {
        guard let value = transform(value) else {
            throw OTelEnvironmentValueError(key: key, value: value, valueType: T.self)
        }
        return value
    }
}

extension OTelEnvironment: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, String)...) {
        values = [String: String](uniqueKeysWithValues: elements.map { ($0.0.lowercased(), $0.1) })
    }
}

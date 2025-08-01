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

#if !(OTLPHTTP || OTLPGRPC)
// Empty when above trait(s) are disabled.
#else
import OTLPCore
import Tracing

extension [Opentelemetry_Proto_Common_V1_KeyValue] {
    /// Create an array of key-value pairs from span attributes.
    ///
    /// - Parameter attributes: The span attributes to cast.
    init(_ attributes: SpanAttributes) {
        var keyValuePairs = [Opentelemetry_Proto_Common_V1_KeyValue]()

        attributes.forEach { key, spanAttribute in
            guard let anyValue = Opentelemetry_Proto_Common_V1_AnyValue(spanAttribute) else {
                // TODO: Log unsupported span attribute type
                return
            }
            let keyValuePair = Opentelemetry_Proto_Common_V1_KeyValue.with {
                $0.key = key
                $0.value = anyValue
            }
            keyValuePairs.append(keyValuePair)
        }

        self = keyValuePairs
    }
}

extension Opentelemetry_Proto_Common_V1_AnyValue {
    /// Create an any value from a `SpanAttribute`.
    ///
    /// - Parameter attribute: The `SpanAttribute` to cast.
    /// - Returns: `nil` if the attribute is unsupported.
    init?(_ attribute: SpanAttribute) {
        switch attribute {
        case .int32(let int32):
            self = .value(Int64(int32), keyPath: \.intValue)
        case .int64(let int64):
            self = .value(int64, keyPath: \.intValue)
        case .int32Array(let items):
            self = .array(items.lazy.map(Int64.init), keyPath: \.intValue)
        case .int64Array(let items):
            self = .array(items, keyPath: \.intValue)
        case .double(let double):
            self = .value(double, keyPath: \.doubleValue)
        case .doubleArray(let items):
            self = .array(items, keyPath: \.doubleValue)
        case .bool(let bool):
            self = .value(bool, keyPath: \.boolValue)
        case .boolArray(let items):
            self = .array(items, keyPath: \.boolValue)
        case .string(let string):
            self = .value(string, keyPath: \.stringValue)
        case .stringArray(let items):
            self = .array(items, keyPath: \.stringValue)
        case .stringConvertible(let stringConvertible):
            self = .value("\(stringConvertible)", keyPath: \.stringValue)
        case .stringConvertibleArray(let items):
            self = .array(items.lazy.map { "\($0)" }, keyPath: \.stringValue)
        default:
            return nil
        }
    }
}

extension Opentelemetry_Proto_Common_V1_AnyValue {
    fileprivate static func value<T>(
        _ value: T,
        keyPath: WritableKeyPath<Opentelemetry_Proto_Common_V1_AnyValue, T>
    ) -> Opentelemetry_Proto_Common_V1_AnyValue {
        .with { $0[keyPath: keyPath] = value }
    }
}

extension Opentelemetry_Proto_Common_V1_AnyValue {
    fileprivate static func array<T>(
        _ items: some Collection<T>,
        keyPath: WritableKeyPath<Opentelemetry_Proto_Common_V1_AnyValue, T>
    ) -> Opentelemetry_Proto_Common_V1_AnyValue {
        .with {
            $0.arrayValue = .init(items: items, keyPath: keyPath)
        }
    }
}

extension Opentelemetry_Proto_Common_V1_ArrayValue {
    fileprivate init<T>(
        items: some Collection<T>,
        keyPath: WritableKeyPath<Opentelemetry_Proto_Common_V1_AnyValue, T>
    ) {
        self = .with {
            $0.values = items.map { item in
                .with { $0[keyPath: keyPath] = item }
            }
        }
    }
}
#endif

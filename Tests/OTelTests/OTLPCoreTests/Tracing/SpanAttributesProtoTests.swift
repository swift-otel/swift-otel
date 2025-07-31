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

import OTLPCore
import Tracing
import XCTest

final class SpanAttributesProtoTests: XCTestCase {
    // MARK: - Key Value

    func test_initKeyValuePairs_withAttributes_setsKeysAndValues() {
        let attributes: SpanAttributes = [
            "key1": 42,
            "key2": "test",
        ]

        let keyValuePairs: [Opentelemetry_Proto_Common_V1_KeyValue] = .init(attributes)

        XCTAssertEqual(keyValuePairs.sorted(by: { $0.key < $1.key }), [
            .with {
                $0.key = "key1"
                $0.value = .with { $0.intValue = 42 }
            },
            .with {
                $0.key = "key2"
                $0.value = .with { $0.stringValue = "test" }
            },
        ])
    }

    func test_initKeyValuePairs_withAttributes_discardsInvalidAttributes() {
        let attributes: SpanAttributes = [
            "valid": 42,
            "invalid": .__DO_NOT_SWITCH_EXHAUSTIVELY_OVER_THIS_ENUM_USE_DEFAULT_INSTEAD,
        ]

        let keyValuePairs: [Opentelemetry_Proto_Common_V1_KeyValue] = .init(attributes)

        XCTAssertEqual(keyValuePairs, [
            .with {
                $0.key = "valid"
                $0.value = .with { $0.intValue = 42 }
            },
        ])
    }

    // MARK: - Any Value

    func test_initAnyValue_withInt32_setsIntValue() {
        let anyValue = Opentelemetry_Proto_Common_V1_AnyValue(.int32(42))

        XCTAssertEqual(anyValue, .with { $0.intValue = 42 })
    }

    func test_initAnyValue_withInt64_setsIntValue() {
        let anyValue = Opentelemetry_Proto_Common_V1_AnyValue(.int64(42))

        XCTAssertEqual(anyValue, .with { $0.intValue = 42 })
    }

    func test_initAnyValue_withInt32Array_setsArrayValue() {
        let anyValue = Opentelemetry_Proto_Common_V1_AnyValue(.int32Array([42, 84]))

        XCTAssertEqual(
            anyValue,
            .with {
                $0.arrayValue = .with {
                    $0.values = [
                        .with { $0.intValue = 42 },
                        .with { $0.intValue = 84 },
                    ]
                }
            }
        )
    }

    func test_initAnyValue_withInt64Array_setsArrayValue() {
        let anyValue = Opentelemetry_Proto_Common_V1_AnyValue(.int64Array([42, 84]))

        XCTAssertEqual(
            anyValue,
            .with {
                $0.arrayValue = .with {
                    $0.values = [
                        .with { $0.intValue = 42 },
                        .with { $0.intValue = 84 },
                    ]
                }
            }
        )
    }

    func test_initAnyValue_withDouble_setsDoubleValue() {
        let anyValue = Opentelemetry_Proto_Common_V1_AnyValue(.double(42))

        XCTAssertEqual(anyValue, .with { $0.doubleValue = 42 })
    }

    func test_initAnyValue_withDoubleArray_setsArrayValue() {
        let anyValue = Opentelemetry_Proto_Common_V1_AnyValue(.doubleArray([42, 84]))

        XCTAssertEqual(
            anyValue,
            .with {
                $0.arrayValue = .with {
                    $0.values = [
                        .with { $0.doubleValue = 42 },
                        .with { $0.doubleValue = 84 },
                    ]
                }
            }
        )
    }

    func test_initAnyValue_withBool_setsBoolValue() {
        let anyValue = Opentelemetry_Proto_Common_V1_AnyValue(.bool(true))

        XCTAssertEqual(anyValue, .with { $0.boolValue = true })
    }

    func test_initAnyValue_withBoolArray_setsArrayValue() {
        let anyValue = Opentelemetry_Proto_Common_V1_AnyValue(.boolArray([true, false]))

        XCTAssertEqual(
            anyValue,
            .with {
                $0.arrayValue = .with {
                    $0.values = [
                        .with { $0.boolValue = true },
                        .with { $0.boolValue = false },
                    ]
                }
            }
        )
    }

    func test_initAnyValue_withString_setsStringValue() {
        let anyValue = Opentelemetry_Proto_Common_V1_AnyValue(.string("test"))

        XCTAssertEqual(anyValue, .with { $0.stringValue = "test" })
    }

    func test_initAnyValue_withStringArray_setsArrayValue() {
        let anyValue = Opentelemetry_Proto_Common_V1_AnyValue(.stringArray(["1", "2"]))

        XCTAssertEqual(
            anyValue,
            .with {
                $0.arrayValue = .with {
                    $0.values = [
                        .with { $0.stringValue = "1" },
                        .with { $0.stringValue = "2" },
                    ]
                }
            }
        )
    }

    func test_initAnyValue_withStringConvertible_setsStringValue() {
        let anyValue = Opentelemetry_Proto_Common_V1_AnyValue(.stringConvertible(42))

        XCTAssertEqual(anyValue, .with { $0.stringValue = "42" })
    }

    func test_initAnyValue_withStringConvertibleArray_setsArrayValue() {
        let anyValue = Opentelemetry_Proto_Common_V1_AnyValue(.stringConvertibleArray([42, true]))

        XCTAssertEqual(
            anyValue,
            .with {
                $0.arrayValue = .with {
                    $0.values = [
                        .with { $0.stringValue = "42" },
                        .with { $0.stringValue = "true" },
                    ]
                }
            }
        )
    }

    func test_initAnyValue_withUnsupportedSpanAttribute_returnsNil() {
        let anyValue = Opentelemetry_Proto_Common_V1_AnyValue(
            .__DO_NOT_SWITCH_EXHAUSTIVELY_OVER_THIS_ENUM_USE_DEFAULT_INSTEAD
        )

        XCTAssertNil(anyValue)
    }
}

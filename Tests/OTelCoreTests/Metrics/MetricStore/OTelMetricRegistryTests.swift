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

@testable import Logging
import struct NIOConcurrencyHelpers.NIOLockedValueBox
@testable import OTelCore
import OTelTesting
import XCTest

final class OTelMetricRegistryTests: XCTestCase {
    func test_identity_SameName_Identical() {
        let registry = OTelMetricRegistry()
        XCTAssertIdentical(
            registry.makeCounter(name: "c"),
            registry.makeCounter(name: "c")
        )
        XCTAssertIdentical(
            registry.makeFloatingPointCounter(name: "f"),
            registry.makeFloatingPointCounter(name: "f")
        )
        XCTAssertIdentical(
            registry.makeGauge(name: "g"),
            registry.makeGauge(name: "g")
        )
        XCTAssertIdentical(
            registry.makeDurationHistogram(name: "d", buckets: []),
            registry.makeDurationHistogram(name: "d", buckets: [])
        )
        XCTAssertIdentical(
            registry.makeValueHistogram(name: "v", buckets: []),
            registry.makeValueHistogram(name: "v", buckets: [])
        )
    }

    func test_identity_sameNameDifferentCase_identical() throws {
        let registry = OTelMetricRegistry()

        XCTAssertIdentical(
            registry.makeCounter(name: "c"),
            registry.makeCounter(name: "C")
        )
        XCTAssertIdentical(
            registry.makeFloatingPointCounter(name: "f"),
            registry.makeFloatingPointCounter(name: "F")
        )
        XCTAssertIdentical(
            registry.makeGauge(name: "G"),
            registry.makeGauge(name: "g")
        )
        XCTAssertIdentical(
            registry.makeDurationHistogram(name: "duration_histogram", buckets: []),
            registry.makeDurationHistogram(name: "dUrAtIoN_hIsToGrAm", buckets: [])
        )
        XCTAssertIdentical(
            registry.makeValueHistogram(name: "value_histogram", buckets: []),
            registry.makeValueHistogram(name: "vAlUe_hIsToGrAm", buckets: [])
        )
    }

    func test_identity_sameNameSameLabels_identical() {
        let registry = OTelMetricRegistry()
        XCTAssertIdentical(
            registry.makeCounter(name: "c", attributes: Set([("one", "1")])),
            registry.makeCounter(name: "c", attributes: Set([("one", "1")]))
        )
        XCTAssertIdentical(
            registry.makeFloatingPointCounter(name: "f", attributes: Set([("one", "1")])),
            registry.makeFloatingPointCounter(name: "f", attributes: Set([("one", "1")]))
        )
        XCTAssertIdentical(
            registry.makeGauge(name: "g", attributes: Set([("one", "1")])),
            registry.makeGauge(name: "g", attributes: Set([("one", "1")]))
        )
        XCTAssertIdentical(
            registry.makeDurationHistogram(name: "d", attributes: Set([("one", "1")]), buckets: []),
            registry.makeDurationHistogram(name: "d", attributes: Set([("one", "1")]), buckets: [])
        )
        XCTAssertIdentical(
            registry.makeValueHistogram(name: "v", attributes: Set([("one", "1")]), buckets: []),
            registry.makeValueHistogram(name: "v", attributes: Set([("one", "1")]), buckets: [])
        )
    }

    func test_identity_differentNamesNoLabels_distinct() {
        let registry = OTelMetricRegistry()
        XCTAssertNotIdentical(
            registry.makeCounter(name: "c1"),
            registry.makeCounter(name: "c2")
        )
        XCTAssertNotIdentical(
            registry.makeFloatingPointCounter(name: "f1"),
            registry.makeFloatingPointCounter(name: "f2")
        )
        XCTAssertNotIdentical(
            registry.makeGauge(name: "g1"),
            registry.makeGauge(name: "g2")
        )
        XCTAssertNotIdentical(
            registry.makeDurationHistogram(name: "h1", buckets: []),
            registry.makeDurationHistogram(name: "h2", buckets: [])
        )
        XCTAssertNotIdentical(
            registry.makeValueHistogram(name: "v1", buckets: []),
            registry.makeValueHistogram(name: "v2", buckets: [])
        )
    }

    func test_identity_sameNameSameLabelKeysDifferentValues_distinct() {
        let registry = OTelMetricRegistry()
        XCTAssertNotIdentical(
            registry.makeCounter(name: "c", attributes: Set([("x", "1"), ("y", "2")])),
            registry.makeCounter(name: "c", attributes: Set([("x", "2"), ("y", "4")]))
        )
        XCTAssertNotIdentical(
            registry.makeFloatingPointCounter(name: "f", attributes: Set([("x", "1"), ("y", "2")])),
            registry.makeFloatingPointCounter(name: "f", attributes: Set([("x", "2"), ("y", "4")]))
        )
        XCTAssertNotIdentical(
            registry.makeGauge(name: "g", attributes: Set([("x", "1"), ("y", "2")])),
            registry.makeGauge(name: "g", attributes: Set([("x", "2"), ("y", "4")]))
        )
        XCTAssertNotIdentical(
            registry.makeDurationHistogram(name: "d", attributes: Set([("x", "1"), ("y", "2")]), buckets: []),
            registry.makeDurationHistogram(name: "d", attributes: Set([("x", "2"), ("y", "4")]), buckets: [])
        )
        XCTAssertNotIdentical(
            registry.makeValueHistogram(name: "v", attributes: Set([("x", "1"), ("y", "2")]), buckets: []),
            registry.makeValueHistogram(name: "v", attributes: Set([("x", "2"), ("y", "4")]), buckets: [])
        )
    }

    func test_identity_sameNameDifferentLabelKeys_distinct() throws {
        let registry = OTelMetricRegistry()

        XCTAssertNotIdentical(
            registry.makeCounter(name: "c", attributes: Set([("x", "1")])),
            registry.makeCounter(name: "c", attributes: Set([("y", "1")]))
        )
        XCTAssertNotIdentical(
            registry.makeFloatingPointCounter(name: "f", attributes: Set([("x", "1")])),
            registry.makeFloatingPointCounter(name: "f", attributes: Set([("y", "1")]))
        )
        XCTAssertNotIdentical(
            registry.makeGauge(name: "g", attributes: Set([("x", "1")])),
            registry.makeGauge(name: "g", attributes: Set([("y", "1")]))
        )
        XCTAssertNotIdentical(
            registry.makeDurationHistogram(name: "d", attributes: Set([("x", "1")]), buckets: []),
            registry.makeDurationHistogram(name: "d", attributes: Set([("y", "1")]), buckets: [])
        )
        XCTAssertNotIdentical(
            registry.makeValueHistogram(name: "v", attributes: Set([("x", "1")]), buckets: []),
            registry.makeValueHistogram(name: "v", attributes: Set([("y", "1")]), buckets: [])
        )
    }

    func test_identity_sameNameAdditionalLabels_distinct() throws {
        let registry = OTelMetricRegistry()

        XCTAssertNotIdentical(
            registry.makeCounter(name: "c", attributes: Set([("x", "1")])),
            registry.makeCounter(name: "c", attributes: Set([("x", "1"), ("y", "1")]))
        )

        XCTAssertNotIdentical(
            registry.makeFloatingPointCounter(name: "f", attributes: Set([("x", "1")])),
            registry.makeFloatingPointCounter(name: "f", attributes: Set([("x", "1"), ("y", "1")]))
        )

        XCTAssertNotIdentical(
            registry.makeGauge(name: "g", attributes: Set([("x", "1")])),
            registry.makeGauge(name: "g", attributes: Set([("x", "1"), ("y", "1")]))
        )

        XCTAssertNotIdentical(
            registry.makeDurationHistogram(name: "d", attributes: Set([("x", "1")]), buckets: []),
            registry.makeDurationHistogram(name: "d", attributes: Set([("x", "1"), ("y", "1")]), buckets: [])
        )
        XCTAssertNotIdentical(
            registry.makeValueHistogram(name: "v", attributes: Set([("x", "1")]), buckets: []),
            registry.makeValueHistogram(name: "v", attributes: Set([("x", "1"), ("y", "1")]), buckets: [])
        )
    }

    func test_identity_sameNameSameLabelsDifferentBuckets_identical() throws {
        let registry = OTelMetricRegistry()

        XCTAssertIdentical(
            registry.makeDurationHistogram(name: "d", attributes: Set([("x", "1")]), buckets: [.seconds(1)]),
            registry.makeDurationHistogram(name: "d", attributes: Set([("x", "1")]), buckets: [.seconds(2)])
        )
        XCTAssertIdentical(
            registry.makeValueHistogram(name: "v", attributes: Set([("x", "1")]), buckets: [1]),
            registry.makeValueHistogram(name: "v", attributes: Set([("x", "1")]), buckets: [2])
        )
    }

    func test_identity_sameNameDifferentIdentity_distinctAndCallsHandler() throws {
        let handler = RecordingDuplicateRegistrationHandler()
        let registry = OTelMetricRegistry(duplicateRegistrationHandler: handler)

        // Start with no invocations.
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 0)

        // Registering a new metric does not invoke handler.
        _ = registry.makeCounter(name: "name", attributes: Set([("x", "1")]))
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 0)

        // Registering the same metric does not invoke handler.
        _ = registry.makeCounter(name: "name", attributes: Set([("x", "1")]))
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 0)

        // Registering a metric with the same identifying fields but different attributes does not invoke handler.
        _ = registry.makeCounter(name: "name", attributes: Set([("y", "2")]))
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 0)

        // Registring a metric of the same type but with a different identifying field invokes the handler once only.
        _ = registry.makeCounter(name: "name", unit: "new_unit", attributes: Set([("x", "1")]))
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 1)
        _ = registry.makeCounter(name: "name", unit: "new_unit", attributes: Set([("x", "1")]))
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 1)

        // OTel spec also states that description is also an identifying field.
        _ = registry.makeCounter(name: "name", unit: "new_unit", description: "new description", attributes: Set([("x", "1")]))
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 2)
        _ = registry.makeCounter(name: "name", unit: "new_unit", description: "new description", attributes: Set([("x", "1")]))
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 2)

        // The kind of instrument is, of course, also an identifying field.
        _ = registry.makeFloatingPointCounter(name: "name", attributes: Set([("x", "1")]))
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 3)
        _ = registry.makeFloatingPointCounter(name: "name", attributes: Set([("x", "1")]))
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 3)
        _ = registry.makeGauge(name: "name", attributes: Set([("x", "1")]))
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 4)
        _ = registry.makeGauge(name: "name", attributes: Set([("x", "1")]))
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 4)

        // Same for histogram...
        _ = registry.makeValueHistogram(name: "name", attributes: Set([("x", "1")]), buckets: [1])
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 5)
        _ = registry.makeValueHistogram(name: "name", attributes: Set([("x", "1")]), buckets: [1])
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 5)

        // ...but currently we do _not_ consider the buckets to be identifying.
        _ = registry.makeValueHistogram(name: "name", attributes: Set([("x", "1")]), buckets: [2])
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 5)

        // While name is an identifying field, it is treated case-insensitively.
        _ = registry.makeCounter(name: "NaMe", attributes: Set([("x", "1")]))
        XCTAssertEqual(handler.invocations.withLockedValue { $0.count }, 5)
    }

    func test_unregisterReregister_withoutLabels() {
        let duplicateRegistrationHandler = RecordingDuplicateRegistrationHandler()
        let registry = OTelMetricRegistry(duplicateRegistrationHandler: duplicateRegistrationHandler)

        registry.unregisterCounter(registry.makeCounter(name: "name"))
        registry.unregisterFloatingPointCounter(registry.makeFloatingPointCounter(name: "name"))
        registry.unregisterGauge(registry.makeGauge(name: "name"))
        registry.unregisterDurationHistogram(registry.makeDurationHistogram(name: "name", buckets: []))
        registry.unregisterValueHistogram(registry.makeValueHistogram(name: "name", buckets: []))
        _ = registry.makeCounter(name: "name")

        XCTAssertEqual(duplicateRegistrationHandler.invocations.withLockedValue { $0 }.count, 0)
    }

    func test_unregisterReregister_withLabels() {
        let duplicateRegistrationHandler = RecordingDuplicateRegistrationHandler()
        let registry = OTelMetricRegistry(duplicateRegistrationHandler: duplicateRegistrationHandler)

        registry.unregisterCounter(registry.makeCounter(name: "name", attributes: Set([("a", "1")])))
        registry.unregisterCounter(registry.makeCounter(name: "name", attributes: Set([("b", "1")])))

        registry.unregisterFloatingPointCounter(registry.makeFloatingPointCounter(name: "name", attributes: Set([("a", "1")])))
        registry.unregisterFloatingPointCounter(registry.makeFloatingPointCounter(name: "name", attributes: Set([("b", "1")])))

        registry.unregisterGauge(registry.makeGauge(name: "name", attributes: Set([("a", "1")])))
        registry.unregisterGauge(registry.makeGauge(name: "name", attributes: Set([("b", "1")])))

        registry.unregisterDurationHistogram(registry.makeDurationHistogram(name: "name", attributes: Set([("a", "1")]), buckets: []))
        registry.unregisterDurationHistogram(registry.makeDurationHistogram(name: "name", attributes: Set([("b", "1")]), buckets: []))

        registry.unregisterValueHistogram(registry.makeValueHistogram(name: "name", attributes: Set([("a", "1")]), buckets: []))
        registry.unregisterValueHistogram(registry.makeValueHistogram(name: "name", attributes: Set([("b", "1")]), buckets: []))

        _ = registry.makeCounter(name: "name", attributes: Set([("a", "1")]))

        XCTAssertEqual(duplicateRegistrationHandler.invocations.withLockedValue { $0 }.count, 0)
    }

    func test_makeCounter_retainsAllMadeInstruments() {
        let registry = OTelMetricRegistry()
        XCTAssertEqual(registry.numDistinctInstruments, 0)
        _ = registry.makeCounter(name: "c1")
        _ = registry.makeCounter(name: "c1")
        _ = registry.makeCounter(name: "c1", attributes: Set([]))
        _ = registry.makeCounter(name: "c1", attributes: Set([]))
        XCTAssertEqual(registry.numDistinctInstruments, 1)
        _ = registry.makeCounter(name: "c1", attributes: Set([("x", "1")]))
        _ = registry.makeCounter(name: "c1", attributes: Set([("x", "1")]))
        XCTAssertEqual(registry.numDistinctInstruments, 2)
        _ = registry.makeCounter(name: "c1", attributes: Set([("x", "2")]))
        _ = registry.makeCounter(name: "c1", attributes: Set([("x", "2")]))
        XCTAssertEqual(registry.numDistinctInstruments, 3)
        _ = registry.makeCounter(name: "c1", attributes: Set([("y", "1")]))
        _ = registry.makeCounter(name: "c1", attributes: Set([("y", "1")]))
        XCTAssertEqual(registry.numDistinctInstruments, 4)
        _ = registry.makeCounter(name: "c2")
        _ = registry.makeCounter(name: "c2")
        XCTAssertEqual(registry.numDistinctInstruments, 5)
    }

    func test_makeFloatingPointCounter_retainsAllMadeInstruments() {
        let registry = OTelMetricRegistry()
        XCTAssertEqual(registry.numDistinctInstruments, 0)
        _ = registry.makeFloatingPointCounter(name: "f1")
        _ = registry.makeFloatingPointCounter(name: "f1")
        _ = registry.makeFloatingPointCounter(name: "f1", attributes: Set([]))
        _ = registry.makeFloatingPointCounter(name: "f1", attributes: Set([]))
        XCTAssertEqual(registry.numDistinctInstruments, 1)
        _ = registry.makeFloatingPointCounter(name: "f1", attributes: Set([("x", "1")]))
        _ = registry.makeFloatingPointCounter(name: "f1", attributes: Set([("x", "1")]))
        XCTAssertEqual(registry.numDistinctInstruments, 2)
        _ = registry.makeFloatingPointCounter(name: "f1", attributes: Set([("x", "2")]))
        _ = registry.makeFloatingPointCounter(name: "f1", attributes: Set([("x", "2")]))
        XCTAssertEqual(registry.numDistinctInstruments, 3)
        _ = registry.makeFloatingPointCounter(name: "f1", attributes: Set([("y", "1")]))
        _ = registry.makeFloatingPointCounter(name: "f1", attributes: Set([("y", "1")]))
        XCTAssertEqual(registry.numDistinctInstruments, 4)
        _ = registry.makeFloatingPointCounter(name: "f2")
        _ = registry.makeFloatingPointCounter(name: "f2")
        XCTAssertEqual(registry.numDistinctInstruments, 5)
    }

    func test_makeGauge_retainsAllMadeInstruments() {
        let registry = OTelMetricRegistry()
        _ = registry.makeGauge(name: "g1")
        _ = registry.makeGauge(name: "g1")
        _ = registry.makeGauge(name: "g1", attributes: Set([]))
        _ = registry.makeGauge(name: "g1", attributes: Set([]))
        XCTAssertEqual(registry.numDistinctInstruments, 1)
        _ = registry.makeGauge(name: "g1", attributes: Set([("x", "1")]))
        _ = registry.makeGauge(name: "g1", attributes: Set([("x", "1")]))
        XCTAssertEqual(registry.numDistinctInstruments, 2)
        _ = registry.makeGauge(name: "g1", attributes: Set([("x", "2")]))
        _ = registry.makeGauge(name: "g1", attributes: Set([("x", "2")]))
        XCTAssertEqual(registry.numDistinctInstruments, 3)
        _ = registry.makeGauge(name: "g1", attributes: Set([("y", "1")]))
        _ = registry.makeGauge(name: "g1", attributes: Set([("y", "1")]))
        XCTAssertEqual(registry.numDistinctInstruments, 4)
        _ = registry.makeGauge(name: "g2")
        _ = registry.makeGauge(name: "g2")
        XCTAssertEqual(registry.numDistinctInstruments, 5)
    }

    func test_makeValueHistogram_retainsAllMadeInstruments() {
        let registry = OTelMetricRegistry()
        _ = registry.makeValueHistogram(name: "v1", buckets: [])
        _ = registry.makeValueHistogram(name: "v1", buckets: [])
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([]), buckets: [0, 1])
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([]), buckets: [0, 1])
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([]), buckets: [1, 2])
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([]), buckets: [1, 2])
        XCTAssertEqual(registry.numDistinctInstruments, 1)
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([("x", "1")]), buckets: [0, 1])
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([("x", "1")]), buckets: [0, 1])
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([("x", "1")]), buckets: [1, 2])
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([("x", "1")]), buckets: [1, 2])
        XCTAssertEqual(registry.numDistinctInstruments, 2)
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([("x", "2")]), buckets: [0, 1])
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([("x", "2")]), buckets: [0, 1])
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([("x", "2")]), buckets: [1, 2])
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([("x", "2")]), buckets: [1, 2])
        XCTAssertEqual(registry.numDistinctInstruments, 3)
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([("y", "1")]), buckets: [0, 1])
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([("y", "1")]), buckets: [0, 1])
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([("y", "1")]), buckets: [1, 2])
        _ = registry.makeValueHistogram(name: "v1", attributes: Set([("y", "1")]), buckets: [1, 2])
        XCTAssertEqual(registry.numDistinctInstruments, 4)
        _ = registry.makeValueHistogram(name: "v2", buckets: [])
        _ = registry.makeValueHistogram(name: "v2", buckets: [])
        XCTAssertEqual(registry.numDistinctInstruments, 5)
    }

    func test_makeDurationHistogram_retainsAllMadeInstruments() {
        let registry = OTelMetricRegistry()
        _ = registry.makeDurationHistogram(name: "d1", buckets: [])
        _ = registry.makeDurationHistogram(name: "d1", buckets: [])
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([]), buckets: [.seconds(1)])
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([]), buckets: [.seconds(1)])
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([]), buckets: [.seconds(2)])
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([]), buckets: [.seconds(2)])
        XCTAssertEqual(registry.numDistinctInstruments, 1)
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([("x", "1")]), buckets: [.seconds(1)])
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([("x", "1")]), buckets: [.seconds(1)])
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([("x", "1")]), buckets: [.seconds(2)])
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([("x", "1")]), buckets: [.seconds(2)])
        XCTAssertEqual(registry.numDistinctInstruments, 2)
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([("x", "2")]), buckets: [.seconds(1)])
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([("x", "2")]), buckets: [.seconds(1)])
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([("x", "2")]), buckets: [.seconds(2)])
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([("x", "2")]), buckets: [.seconds(2)])
        XCTAssertEqual(registry.numDistinctInstruments, 3)
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([("y", "1")]), buckets: [.seconds(1)])
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([("y", "1")]), buckets: [.seconds(1)])
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([("y", "1")]), buckets: [.seconds(2)])
        _ = registry.makeDurationHistogram(name: "d1", attributes: Set([("y", "1")]), buckets: [.seconds(2)])
        XCTAssertEqual(registry.numDistinctInstruments, 4)
        _ = registry.makeDurationHistogram(name: "d2", buckets: [])
        _ = registry.makeDurationHistogram(name: "d2", buckets: [])
        XCTAssertEqual(registry.numDistinctInstruments, 5)
    }
}

final class DuplicateRegistrationHandlerTests: XCTestCase {
    func test_LoggingDuplicateRegistrationHandler() {
        let recordingLogHandler = RecordingLogHandler()
        let recordingLogger = Logger(label: "test", recordingLogHandler)
        let handler = WarningDuplicateRegistrationHandler(logger: recordingLogger)
        handler.handle(
            newRegistration: .counter(name: "name"),
            existingRegistrations: [.gauge(name: "name"), .histogram(name: "name")]
        )
        XCTAssertEqual(recordingLogHandler.warningCount, 1)
    }

    func test_DuplicateRegistrationHandler_selection() {
        XCTAssert(OTelMetricRegistry(onDuplicateRegistration: .warn).storage.withLockedValue { $0 }.duplicateRegistrationHandler is WarningDuplicateRegistrationHandler)
        XCTAssert(OTelMetricRegistry(onDuplicateRegistration: .crash).storage.withLockedValue { $0 }.duplicateRegistrationHandler is FatalErrorDuplicateRegistrationHandler)
    }

    func test_DuplicateRegistrationHandler_default() {
        XCTAssert(OTelMetricRegistry().storage.withLockedValue { $0 }.duplicateRegistrationHandler is WarningDuplicateRegistrationHandler)
    }
}

extension OTelMetricRegistry {
    // Overload with logging disabled.
    convenience init(duplicateRegistrationHandler: some DuplicateRegistrationHandler) {
        self.init(duplicateRegistrationHandler: duplicateRegistrationHandler, logger: ._otelDisabled)
    }

    // Overload with logging disabled.
    convenience init(onDuplicateRegistration: DuplicateRegistrationBehavior = .warn) {
        self.init(onDuplicateRegistration: onDuplicateRegistration, logger: ._otelDisabled)
    }

    var numDistinctInstruments: Int {
        let metrics = storage.withLockedValue { $0 }
        let x: [Int] = [
            metrics.counters.values.map(\.values.count).reduce(0, +),
            metrics.floatingPointCounters.values.map(\.values.count).reduce(0, +),
            metrics.gauges.values.map(\.values.count).reduce(0, +),
            metrics.durationHistograms.values.map(\.values.count).reduce(0, +),
            metrics.valueHistograms.values.map(\.values.count).reduce(0, +),
        ]
        return x.reduce(0, +)
    }
}

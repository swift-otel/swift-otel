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

import Logging
import struct NIOConcurrencyHelpers.NIOLockedValueBox

/// A registry for metric instruments.
///
/// The registry owns the mapping from instrument identfier and attributes to the stateful instrument for recording
/// measurements.
public final class OTelMetricRegistry: Sendable {
    private let logger = Logger(label: "OTelMetricRegistry")

    struct Storage {
        var counters = [InstrumentIdentifier: [Set<Attribute>: Counter]]()
        var floatingPointCounters = [InstrumentIdentifier: [Set<Attribute>: FloatingPointCounter]]()
        var gauges = [InstrumentIdentifier: [Set<Attribute>: Gauge]]()
        var valueHistograms = [InstrumentIdentifier: [Set<Attribute>: ValueHistogram]]()
        var durationHistograms = [InstrumentIdentifier: [Set<Attribute>: DurationHistogram]]()

        var registrations = [String: Set<InstrumentIdentifier>]()
        let duplicateRegistrationHandler: DuplicateRegistrationHandler?

        mutating func register(_ identifier: InstrumentIdentifier, forName name: String) {
            if var existingRegistrations = registrations[name] {
                duplicateRegistrationHandler?.handle(newRegistration: identifier, existingRegistrations: existingRegistrations)
                existingRegistrations.insert(identifier)
                registrations[name] = existingRegistrations
            } else {
                registrations[name] = [identifier]
            }
        }

        mutating func unregister(_ identifier: InstrumentIdentifier, forName name: String) {
            guard var existingRegistrations = registrations[name] else { return }
            existingRegistrations.remove(identifier)
            if existingRegistrations.isEmpty {
                registrations.removeValue(forKey: name)
            }
        }
    }

    let storage: NIOLockedValueBox<Storage>

    /// Behavior when a duplicate instrument registration occurs.
    ///
    /// A duplicate instrument registration occurs when more than one instrument of the same name is created with
    /// different _identifying fields_.
    public struct DuplicateRegistrationBehavior: Sendable {
        enum Behavior: Sendable {
            case warn, crash
        }

        var behavior: Behavior

        /// Emits a log message at warning level.
        public static let warn = Self(behavior: .warn)

        /// Crashes with a fatal error.
        public static let crash = Self(behavior: .crash)
    }

    init(duplicateRegistrationHandler: some DuplicateRegistrationHandler) {
        self.storage = .init(Storage(duplicateRegistrationHandler: duplicateRegistrationHandler))
    }

    /// Create a new ``OTelMetricRegistry``.
    /// - Parameters:
    ///   - onDuplicateRegistration: Action to take when more than one instrument of the same name is created with
    ///     different identifying fields.
    ///
    /// - Seealso: ``OTelMetricRegistry/DuplicateRegistrationBehavior``.
    public convenience init(onDuplicateRegistration: DuplicateRegistrationBehavior = .warn) {
        switch onDuplicateRegistration.behavior {
        case .warn:
            self.init(duplicateRegistrationHandler: WarningDuplicateRegistrationHandler.default)
        case .crash:
            self.init(duplicateRegistrationHandler: FatalErrorDuplicateRegistrationHandler())
        }
    }

    func makeCounter(name: String, unit: String? = nil, description: String? = nil, attributes: Set<Attribute> = []) -> Counter {
        storage.withLockedValue { storage in
            let identifier = InstrumentIdentifier.counter(name: name, unit: unit, description: description)
            if var existingInstruments = storage.counters[identifier] {
                if let existingInstrument = existingInstruments[attributes] {
                    return existingInstrument
                }
                let newInstrument = Counter(name: name, unit: unit, description: description, attributes: attributes)
                existingInstruments[attributes] = newInstrument
                storage.counters[identifier] = existingInstruments
                return newInstrument
            }
            storage.register(identifier, forName: name)
            let newInstrument = Counter(name: name, unit: unit, description: description, attributes: attributes)
            storage.counters[identifier] = [attributes: newInstrument]
            return newInstrument
        }
    }

    func makeFloatingPointCounter(name: String, unit: String? = nil, description: String? = nil, attributes: Set<Attribute> = []) -> FloatingPointCounter {
        storage.withLockedValue { storage in
            let identifier = InstrumentIdentifier.floatingPointCounter(name: name, unit: unit, description: description)
            if var existingInstruments = storage.floatingPointCounters[identifier] {
                if let existingInstrument = existingInstruments[attributes] {
                    return existingInstrument
                }
                let newInstrument = FloatingPointCounter(name: name, unit: unit, description: description, attributes: attributes)
                existingInstruments[attributes] = newInstrument
                storage.floatingPointCounters[identifier] = existingInstruments
                return newInstrument
            }
            storage.register(identifier, forName: name)
            let newInstrument = FloatingPointCounter(name: name, unit: unit, description: description, attributes: attributes)
            storage.floatingPointCounters[identifier] = [attributes: newInstrument]
            return newInstrument
        }
    }

    func makeGauge(name: String, unit: String? = nil, description: String? = nil, attributes: Set<Attribute> = []) -> Gauge {
        storage.withLockedValue { storage in
            let identifier = InstrumentIdentifier.gauge(name: name, unit: unit, description: description)
            if var existingInstruments = storage.gauges[identifier] {
                if let existingInstrument = existingInstruments[attributes] {
                    return existingInstrument
                }
                let newInstrument = Gauge(name: name, unit: unit, description: description, attributes: attributes)
                existingInstruments[attributes] = newInstrument
                storage.gauges[identifier] = existingInstruments
                return newInstrument
            }
            storage.register(identifier, forName: name)
            let newInstrument = Gauge(name: name, unit: unit, description: description, attributes: attributes)
            storage.gauges[identifier] = [attributes: newInstrument]
            return newInstrument
        }
    }

    func makeDurationHistogram(name: String, unit: String? = nil, description: String? = nil, attributes: Set<Attribute> = [], buckets: [Duration]) -> DurationHistogram {
        storage.withLockedValue { storage in
            let identifier = InstrumentIdentifier.histogram(name: name, unit: unit, description: description)
            if var existingInstruments = storage.durationHistograms[identifier] {
                if let existingInstrument = existingInstruments[attributes] {
                    return existingInstrument
                }
                let newInstrument = DurationHistogram(name: name, unit: unit, description: description, attributes: attributes, buckets: buckets)
                existingInstruments[attributes] = newInstrument
                storage.durationHistograms[identifier] = existingInstruments
                return newInstrument
            }
            storage.register(identifier, forName: name)
            let newInstrument = DurationHistogram(name: name, unit: unit, description: description, attributes: attributes, buckets: buckets)
            storage.durationHistograms[identifier] = [attributes: newInstrument]
            return newInstrument
        }
    }

    func makeValueHistogram(name: String, unit: String? = nil, description: String? = nil, attributes: Set<Attribute> = [], buckets: [Double]) -> ValueHistogram {
        storage.withLockedValue { storage in
            let identifier = InstrumentIdentifier.histogram(name: name, unit: unit, description: description)
            if var existingInstruments = storage.valueHistograms[identifier] {
                if let existingInstrument = existingInstruments[attributes] {
                    return existingInstrument
                }
                let newInstrument = ValueHistogram(name: name, unit: unit, description: description, attributes: attributes, buckets: buckets)
                existingInstruments[attributes] = newInstrument
                storage.valueHistograms[identifier] = existingInstruments
                return newInstrument
            }
            storage.register(identifier, forName: name)
            let newInstrument = ValueHistogram(name: name, unit: unit, description: description, attributes: attributes, buckets: buckets)
            storage.valueHistograms[identifier] = [attributes: newInstrument]
            return newInstrument
        }
    }

    func unregisterCounter(_ counter: Counter) {
        let identifier = counter.instrumentIdentifier
        self.storage.withLockedValue { storage in
            if var existingInstrument = storage.counters[identifier] {
                existingInstrument.removeValue(forKey: counter.attributes)
                if existingInstrument.isEmpty {
                    storage.counters.removeValue(forKey: identifier)
                    storage.unregister(identifier, forName: identifier.name)
                } else {
                    storage.counters[identifier] = existingInstrument
                }
            }
        }
    }

    func unregisterFloatingPointCounter(_ floatingPointCounter: FloatingPointCounter) {
        let identifier = floatingPointCounter.instrumentIdentifier
        self.storage.withLockedValue { storage in
            if var existingInstrument = storage.floatingPointCounters[identifier] {
                existingInstrument.removeValue(forKey: floatingPointCounter.attributes)
                if existingInstrument.isEmpty {
                    storage.floatingPointCounters.removeValue(forKey: identifier)
                    storage.unregister(identifier, forName: identifier.name)
                } else {
                    storage.floatingPointCounters[identifier] = existingInstrument
                }
            }
        }
    }

    func unregisterGauge(_ gauge: Gauge) {
        let identifier = gauge.instrumentIdentifier
        self.storage.withLockedValue { storage in
            if var existingInstrument = storage.gauges[identifier] {
                existingInstrument.removeValue(forKey: gauge.attributes)
                if existingInstrument.isEmpty {
                    storage.gauges.removeValue(forKey: identifier)
                    storage.unregister(identifier, forName: identifier.name)
                } else {
                    storage.gauges[identifier] = existingInstrument
                }
            }
        }
    }

    func unregisterDurationHistogram(_ histogram: DurationHistogram) {
        let identifier = histogram.instrumentIdentifier
        self.storage.withLockedValue { storage in
            if var existingInstrument = storage.durationHistograms[identifier] {
                existingInstrument.removeValue(forKey: histogram.attributes)
                if existingInstrument.isEmpty {
                    storage.durationHistograms.removeValue(forKey: identifier)
                    storage.unregister(identifier, forName: identifier.name)
                } else {
                    storage.durationHistograms[identifier] = existingInstrument
                }
            }
        }
    }

    func unregisterValueHistogram(_ histogram: ValueHistogram) {
        let identifier = histogram.instrumentIdentifier
        self.storage.withLockedValue { storage in
            if var existingInstrument = storage.valueHistograms[identifier] {
                existingInstrument.removeValue(forKey: histogram.attributes)
                if existingInstrument.isEmpty {
                    storage.valueHistograms.removeValue(forKey: identifier)
                    storage.unregister(identifier, forName: identifier.name)
                } else {
                    storage.valueHistograms[identifier] = existingInstrument
                }
            }
        }
    }
}

struct InstrumentIdentifier: Equatable, Hashable, Sendable {
    var name: String
    var unit: String?
    var description: String?
    enum InstrumentKind { case counter, floatingPointCounter, gauge, histogram }
    var kind: InstrumentKind

    private init(name: String, unit: String? = nil, description: String? = nil, kind: InstrumentKind) {
        self.name = name.lowercased()
        self.unit = unit
        self.description = description
        self.kind = kind
    }

    static func counter(name: String, unit: String? = nil, description: String? = nil) -> Self {
        self.init(name: name, unit: unit, description: description, kind: .counter)
    }

    static func floatingPointCounter(name: String, unit: String? = nil, description: String? = nil) -> Self {
        self.init(name: name, unit: unit, description: description, kind: .floatingPointCounter)
    }

    static func gauge(name: String, unit: String? = nil, description: String? = nil) -> Self {
        self.init(name: name, unit: unit, description: description, kind: .gauge)
    }

    static func histogram(name: String, unit: String? = nil, description: String? = nil) -> Self {
        self.init(name: name, unit: unit, description: description, kind: .histogram)
    }
}

protocol IdentifiableInstrument {
    var instrumentIdentifier: InstrumentIdentifier { get }
}

extension Counter: IdentifiableInstrument {
    var instrumentIdentifier: InstrumentIdentifier { .counter(name: name, unit: unit, description: description) }
}

extension FloatingPointCounter: IdentifiableInstrument {
    var instrumentIdentifier: InstrumentIdentifier { .floatingPointCounter(name: name, unit: unit, description: description) }
}

extension Gauge: IdentifiableInstrument {
    var instrumentIdentifier: InstrumentIdentifier { .gauge(name: name, unit: unit, description: description) }
}

extension Histogram: IdentifiableInstrument {
    var instrumentIdentifier: InstrumentIdentifier { .histogram(name: name, unit: unit, description: description) }
}

protocol DuplicateRegistrationHandler: Sendable {
    func handle(newRegistration: InstrumentIdentifier, existingRegistrations: Set<InstrumentIdentifier>)
}

struct FatalErrorDuplicateRegistrationHandler: DuplicateRegistrationHandler {
    func handle(newRegistration: InstrumentIdentifier, existingRegistrations: Set<InstrumentIdentifier>) {
        fatalError("""
        Duplicate instrument registration for name: \(newRegistration.name)
        ---
        Instrument \(newRegistration) conflicts with existing instruments: \(existingRegistrations).
        """)
    }
}

struct WarningDuplicateRegistrationHandler: DuplicateRegistrationHandler {
    let logger: Logger

    func handle(newRegistration: InstrumentIdentifier, existingRegistrations: Set<InstrumentIdentifier>) {
        self.logger.warning("Duplicate instrument registration", metadata: [
            "newRegistration": "\(newRegistration)",
            "existingRegistrations": .array(existingRegistrations.map { "\($0)" }),
        ])
    }

    static let `default` = Self(logger: Logger(label: "OTelMetricRegistry"))
}

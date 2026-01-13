//
//  OTelProfileExporter.swift
//  swift-otel
//

import ServiceLifecycle

protocol OTelProfileExporter: Service, Sendable {
    func export(_ batch: some Collection<Opentelemetry_Proto_Profiles_V1development_ResourceProfiles> & Sendable, _ dictionary: Opentelemetry_Proto_Profiles_V1development_ProfilesDictionary) async throws

    func forceFlush() async throws

    func shutdown() async
}

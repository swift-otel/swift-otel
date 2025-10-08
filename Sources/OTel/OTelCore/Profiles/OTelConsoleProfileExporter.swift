//
//  OTelConsoleProfileExporter.swift
//  swift-otel
//

import ServiceLifecycle

struct OTelConsoleProfileExporter: OTelProfileExporter {
    func run() async throws {
        // No background work needed, but we'll keep the run method running until its cancelled.
        try await gracefulShutdown()
    }

    func export(_ batch: some Collection<Opentelemetry_Proto_Profiles_V1development_ResourceProfiles> & Sendable) {
        for profile in batch {
            try? print(profile.jsonString())
        }
    }

    func forceFlush() {}
    func shutdown() {}
}

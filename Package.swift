// swift-tools-version:6.1
import PackageDescription

let sharedSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("InternalImportsByDefault"),
    PlatformRequirements.clockAPI.availabilityMacro,
    PlatformRequirements.gRPCSwift.availabilityMacro,
]

let package = Package(
    name: "swift-otel",
    platforms: PlatformRequirements.clockAPI.supportedPlatforms,
    products: [
        .library(name: "OTel", targets: ["OTel"]),
    ],
    traits: [
        .trait(name: "OTLPHTTP", description: "OTLP/HTTP exporter support"),
        .trait(name: "OTLPGRPC", description: "OTLP/gRPC exporter support"),
        .default(enabledTraits: ["OTLPHTTP", "OTLPGRPC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.4.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.0.2"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.4.1"),
        .package(url: "https://github.com/swift-otel/swift-w3c-trace-context.git", exact: "1.0.0-beta.3"),
        .package(url: "https://github.com/apple/swift-profile-recorder.git", .upToNextMinor(from: "0.3.0")),

        // MARK: - OTLPCore

        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.31.0"),

        // MARK: - OTLPGRPC

        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "2.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "2.0.0"),

        // MARK: - OTLPHTTP

        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.25.0"),

        // MARK: - Plugins

        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "OTel",
            dependencies: [
                // API
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                // Core
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "DequeModule", package: "swift-collections"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "W3CTraceContext", package: "swift-w3c-trace-context"),
                // OTLP exporter -- only when OTLPHTTP and/or OTLPGRPC traits are enabled.
                .product(name: "SwiftProtobuf", package: "swift-protobuf", condition: .when(traits: ["OTLPHTTP", "OTLPGRPC"], alwaysIncludeOnKnownBrokenToolchains: true)),
                // OTLP/HTTP exporter -- only when OTLPHTTP trait is enabled.
                .product(name: "AsyncHTTPClient", package: "async-http-client", condition: .when(traits: ["OTLPHTTP"], alwaysIncludeOnKnownBrokenToolchains: true)),
                .product(name: "NIOSSL", package: "swift-nio-ssl", condition: .when(traits: ["OTLPHTTP"], alwaysIncludeOnKnownBrokenToolchains: true)),
                // OTLP/GRPC exporter -- only when OTLPGRPC trait is enabled.
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf", condition: .when(traits: ["OTLPGRPC"], alwaysIncludeOnKnownBrokenToolchains: true)),
                .product(name: "GRPCCore", package: "grpc-swift-2", condition: .when(traits: ["OTLPGRPC"], alwaysIncludeOnKnownBrokenToolchains: true)),
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport", condition: .when(traits: ["OTLPGRPC"], alwaysIncludeOnKnownBrokenToolchains: true)),
                // TODO: think about how to put this behind a trait
                .product(name: "ProfileRecorderServer", package: "swift-profile-recorder"),
            ],
            swiftSettings: sharedSwiftSettings
        ),

        .testTarget(
            name: "OTelTests",
            dependencies: [
                .target(name: "OTel"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)

extension TargetDependencyCondition {
    static func when(traits: Set<String>, alwaysIncludeOnKnownBrokenToolchains: Bool) -> Self? {
        if alwaysIncludeOnKnownBrokenToolchains {
            // NOTE: Once 6.2.1 has been out for some reasonable time, we could potentially remove this workaround.
            // See: https://github.com/swiftlang/swift-package-manager/pull/9141
            #if compiler(>=6.2.0) && compiler(<6.2.1)
            return nil
            #else
            return .when(traits: traits)
            #endif
        } else {
            return .when(traits: traits)
        }
    }
}

/// A set of related platform requirements to prevent version drift in availability annotations and package platforms.
struct PlatformRequirements {
    private let name, macOS, iOS, tvOS, watchOS, visionOS: String

    /// Platform requirements for use within a package manifest.
    var supportedPlatforms: [SupportedPlatform] {
        [.macOS(macOS), .iOS(iOS), .tvOS(tvOS), .watchOS(watchOS), .visionOS(visionOS)]
    }

    /// Swift setting to enable a custom availability macro for this set of platform requirements.
    ///
    /// This creates a shorthand availability annotation that can be used instead of writing out the full platform list.
    ///
    /// First add the Swift setting to your targets:
    ///
    /// ```swift
    /// .target(
    ///     name: "MyTarget",
    ///     swiftSettings: [PlatformRequirements.myFeature.availabilityMacro]
    /// )
    /// ```
    ///
    /// Then in your source code, use the annotation:
    ///
    /// ```swift
    /// @available(MyFeature, *)
    /// func newAPIMethod() { ... }
    /// ```
    ///
    /// This is equivalent to the following, but allows a clear reason for why the annotation exists and a central way
    /// to manage the associated platform version requirements:
    ///
    /// ```swift
    /// @available(macOS 13, iOS 16, tvOS 16, watchOS 9, visionOS 1, *)
    /// func newAPIMethod() { ... }
    /// ```
    var availabilityMacro: SwiftSetting {
        .enableExperimentalFeature("AvailabilityMacro=\(name) : macOS \(macOS), iOS \(iOS), tvOS \(tvOS), watchOS \(watchOS), visionOS \(visionOS)")
    }

    static let clockAPI = Self(name: "ClockAPI", macOS: "13", iOS: "16", tvOS: "16", watchOS: "9", visionOS: "1")
    static let gRPCSwift = Self(name: "gRPCSwift", macOS: "15", iOS: "18", tvOS: "18", watchOS: "11", visionOS: "2")
}

if ["true", "y", "yes", "on", "1"].contains(Context.environment["OTEL_ENABLE_BENCHMARKS"]?.lowercased()) {
    package.dependencies.append(
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.27.0")
    )
    package.targets.append(
        .executableTarget(
            name: "OTelBenchmarks",
            dependencies: [
                "OTel",
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/OTelBenchmarks",
            swiftSettings: sharedSwiftSettings,
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    )
}

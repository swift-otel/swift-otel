// swift-tools-version:6.1
import PackageDescription

let sharedSwiftSettings: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency=complete")]

let package = Package(
    name: "swift-otel",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "OTel", targets: ["OTel"]),
    ],
    traits: [
        .trait(name: "OTLPHTTP"),
        .trait(name: "OTLPGRPC"),
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

        // MARK: - OTLP

        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.23.1"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.25.0"),

        // MARK: - Plugins

        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "OTel",
            dependencies: [
                .target(name: "OTelCore"),
                .target(name: "OTLPGRPC", condition: .when(traits: ["OTLPGRPC"])),
                .target(name: "OTLPHTTP", condition: .when(traits: ["OTLPHTTP"])),

                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "OTelTests",
            dependencies: [
                .target(name: "OTel"),
            ]
        ),

        .target(
            name: "OTelCore",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "DequeModule", package: "swift-collections"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "CoreMetrics", package: "swift-metrics"),
                .product(name: "W3CTraceContext", package: "swift-w3c-trace-context"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "OTelCoreTests",
            dependencies: [
                .target(name: "OTelCore"),
                .target(name: "OTelTesting"),
            ],
            swiftSettings: sharedSwiftSettings
        ),

        .target(
            name: "OTelTesting",
            dependencies: [
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .target(name: "OTelCore"),
            ],
            swiftSettings: sharedSwiftSettings
        ),

        // MARK: - OTLP

        .target(
            name: "OTLPCore",
            dependencies: [
                .target(name: "OTelCore"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "OTLPCoreTests",
            dependencies: [
                .target(name: "OTLPCore"),
                .target(name: "OTelTesting"),
            ],
            swiftSettings: sharedSwiftSettings
        ),

        .target(
            name: "OTLPGRPC",
            dependencies: [
                .target(name: "OTelCore"),
                .target(name: "OTLPCore"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "NIOHTTP2", package: "swift-nio-http2"),
                .product(name: "W3CTraceContext", package: "swift-w3c-trace-context"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "OTLPGRPCTests",
            dependencies: [
                .target(name: "OTLPGRPC"),
                .target(name: "OTelTesting"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ],
            swiftSettings: sharedSwiftSettings
        ),

        .target(
            name: "OTLPHTTP",
            dependencies: [
                .target(name: "OTelCore"),
                .target(name: "OTLPCore"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "OTLPHTTPTests",
            dependencies: [
                .target(name: "OTel"),
                .target(name: "OTelCore"),
                .target(name: "OTelTesting"),
                .target(name: "OTLPCore"),
                .target(name: "OTLPHTTP"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
            ],
            swiftSettings: sharedSwiftSettings
        ),

    ],
    swiftLanguageModes: [.version("6"), .v5]
)

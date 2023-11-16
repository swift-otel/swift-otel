// swift-tools-version:5.9
import PackageDescription

let sharedSwiftSettings: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "swift-otel",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "OpenTelemetry", targets: ["OpenTelemetry"]),
        .library(name: "OTLP", targets: ["OTLP"]),
        .library(name: "OTLPGRPC", targets: ["OTLPGRPC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),

        // MARK: - OTLP

        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.0.0"),

        // MARK: - Plugins

        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "OpenTelemetry",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "DequeModule", package: "swift-collections"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "OpenTelemetryTests",
            dependencies: [
                .target(name: "OpenTelemetry"),
                .target(name: "OTelTesting"),
            ],
            swiftSettings: sharedSwiftSettings
        ),

        .target(
            name: "OTelTesting",
            dependencies: [
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .target(name: "OpenTelemetry"),
            ],
            swiftSettings: sharedSwiftSettings
        ),

        // MARK: - OTLP

        .target(
            name: "OTLP",
            dependencies: [
                .target(name: "OpenTelemetry"),
                .target(name: "OTLPGRPC"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "OTLPTests",
            dependencies: [
                .target(name: "OTLP"),
                .target(name: "OTelTesting"),
            ],
            swiftSettings: sharedSwiftSettings
        ),

        .target(
            name: "OTLPCore",
            dependencies: [
                .target(name: "OpenTelemetry"),
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
                .target(name: "OpenTelemetry"),
                .target(name: "OTLPCore"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "NIOHTTP2", package: "swift-nio-http2"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "OTLPGRPCTests",
            dependencies: [
                .target(name: "OTLPGRPC"),
                .target(name: "OTelTesting"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
    ]
)

// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "swift-otel-server-example",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(name: "swift-otel", path: "../.."),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.4.1"),
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "ServerExample",
            dependencies: [
                .product(name: "OTel", package: "swift-otel"),
                .product(name: "OTLPGRPC", package: "swift-otel"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
            ]
        ),
    ]
)

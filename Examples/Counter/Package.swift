// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "swift-otel-counter",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "counter", targets: ["Example"]),
    ],
    dependencies: [
        .package(name: "swift-otel", path: "../.."),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.4.1"),
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.4.1"),
    ],
    targets: [
        .executableTarget(
            name: "Example",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "OTel", package: "swift-otel"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ]
        ),
    ]
)

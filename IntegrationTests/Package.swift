// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "swift-otel-integration-tests",
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
    ],
    targets: [
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                .product(name: "OTel", package: "swift-otel"),
                .product(name: "OTLPGRPC", package: "swift-otel"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        )
    ],
    swiftLanguageVersions: [.version("6"), .v5]
)

// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "hello-world-grafana-lgtm",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-otel/swift-otel.git", from: "1.0.0", traits: ["OTLPGRPC"]),
    ],
    targets: [
        .executableTarget(
            name: "HelloWorldHummingbirdServer",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "OTel", package: "swift-otel"),
            ]
        ),
    ]
)

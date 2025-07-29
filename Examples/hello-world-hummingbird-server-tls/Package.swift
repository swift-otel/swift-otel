// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "hello-world-hummingbird-server-tls",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        // TODO: update this to `from: 1.0.0` when we release 1.0.
        .package(url: "https://github.com/swift-otel/swift-otel.git", exact: "1.0.0-aplha.1"),
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

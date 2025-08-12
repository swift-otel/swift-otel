// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "hello-world-vapor-server-otlp-http-protobuf",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
        // TODO: update this to `from: 1.0.0` when we release 1.0.
        .package(url: "https://github.com/swift-otel/swift-otel.git", exact: "1.0.0-alpha.2", traits: ["OTLPHTTP"]),
    ],
    targets: [
        .executableTarget(
            name: "HelloWorldVaporServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "OTel", package: "swift-otel"),
            ]
        ),
    ]
)

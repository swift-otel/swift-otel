// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "hummingbird-vapor-async-http-client",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/swift-otel/swift-otel.git", from: "1.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.29.1"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "HummingbirdServer",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "OTel", package: "swift-otel"),
            ],
        ),
        .executableTarget(
            name: "VaporServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "OTel", package: "swift-otel"),
            ],
        ),
    ],
)

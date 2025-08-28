// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "swift-otel-benchmarks",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.29.0"),
        .package(name: "swift-otel", path: "..", traits: ["OTLPHTTP", "OTLPGRPC"]),
    ],
    targets: [
        .executableTarget(
            name: "OTelBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "OTel", package: "swift-otel"),
            ],
            path: "Benchmarks/",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark"),
            ]
        ),
    ]
)

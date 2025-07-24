# Swift OTel

An OTLP backend for Swift Log, Swift Metrics, and Swift Distributed Tracing.

- 📚 **Documentation** is available on the [Swift Package Index][TODO-docs-need-fixing]
- 💻 **Examples** are available in the [Examples][examples] directory
- 🪪 **License** is Apache 2.0, repeated in [LICENSE][license]
- 🔀 **Related Repositories**:
  - [`swift-log`][swift-log] Logging API package for Swift.
  - [`swift-metrics`][swift-metrics] Metrics API package for Swift.
  - [`swift-distributed-tracing`][swift-distributed-tracing] Tracing API package for Swift.

## Quickstart

Add the dependencies to your package and target:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Application",
    platforms: [.macOS("13.0")],
    dependencies: [
        // ...
        // NOTE: this will use `from: "1.0.0"` once its available.
        .package(url: "https://github.com/swift-otel/swift-otel.git", exact: "1.0.0-alpha.1"),
    ],
    targets: [
        .executableTarget(
            name: "Server",
            dependencies: [
                // ...
                .product(name: "OTel", package: "swift-otel"),
            ]
        )
    ]
)
```

Then in your target:

```swift
import OTel

// Bootstrap observability backends.
let observability = try OTel.bootstrap()

// Run the observability background tasks, alongside your application logic.
await withThrowingTaskGroup { group in
    group.addTask { try await observability.run() }
    // Your application logic here...
}
```

### Swift Service Lifecycle integration

The value returned from the bootstrap API conforms to `Service` so it can be run within a `ServiceGroup`:

```swift
import OTel
import ServiceLifecycle

// Bootstrap observability backends.
let observability = try OTel.bootstrap()

// Run observability services in a service group with your services.
let service: Service = // ...
let serviceGroup = ServiceGroup(services: [observability, service], logger: .init(label: "ServiceGroup"))
try await serviceGroup.run()
```

Or, if another dependency has APIs for running additional services, you can use those. For example, using Hummingbird:

```swift
import OTel
import Hummingbird

// Bootstrap observability backends.
let observability = try OTel.bootstrap()

// Create an HTTP server with instrumentation middlewares.
let router = Router()
router.middlewares.add(TracingMiddleware())
router.middlewares.add(MetricsMiddleware())
router.middlewares.add(LogRequestsMiddleware(.info))
router.get("hello") { _, _ in "hello" }
var app = Application(router: router)

// Add the observability service to the Hummingbird service group and run the server.
app.addServices(observability)
try await app.runService()
```

[docs]: https://swiftpackageindex.com/swift-otel/swift-otel/documentation
[examples]: https://github.com/swift-otel/swift-otel/tree/main/Examples/
[license]: https://github.com/swift-otel/swift-otel/tree/main/LICENSE.txt
[swift-log]: https://github.com/apple/swift-log
[swift-metrics]: https://github.com/apple/swift-metrics
[swift-distributed-tracing]: https://github.com/apple/swift-distributed-tracing

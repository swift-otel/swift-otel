# Proposal: Revised public API to support 1.0 roadmap

- Author: [Si Beaumont](https://github.com/simonjbeaumont)
- Discussion: [Swift Forums](https://forums.swift.org/t/swift-otel-proposed-revised-api-for-1-0-release/80214/)
- Status: Accepted

## Introduction

Swift OTel provides an OTLP backend for the Swift observability packages (Swift Log, Swift Metrics, and Swift
Distributed Tracing). This is an important package for the server ecosystem and so we would like to converge on a stable
1.0 release.

As part of the 1.0 release we would like to revise the public API to simplify adoption and maintenance. In discussing
the proposed API, we must also consider the other features that are planned for the 1.0 release:

- Support for OTLP Logging backend.

- Update existing gRPC exporter to use gRPC Swift v2.

- Add support for an OTLP/HTTP exporter.

- Better support spec-defined configuration, including (m)TLS.

- Reduced ceremony for bootstrapping the Swift observability backends.

Note that this package is not focused on providing a full "OTel SDK", and so the API is focussed only on bootstrapping
the Swift observability backends with OTLP exporters.

The remaining part of this proposal focuses on the proposed API changes.

## Existing API

The below code is the current, most concise way to bootstrap the observability backends.
        
```swift
// Bootstrap the logging backend with the OTel metadata provider which includes span IDs in logging messages.
LoggingSystem.bootstrap { label in
    var handler = StreamLogHandler.standardError(label: label, metadataProvider: .otel)
    handler.logLevel = .trace
    return handler
}

// Configure OTel resource detection to automatically apply helpful attributes to events.
let environment = OTelEnvironment.detected()
let resourceDetection = OTelResourceDetection(detectors: [
    OTelProcessResourceDetector(),
    OTelEnvironmentResourceDetector(environment: environment),
    .manual(OTelResource(attributes: ["service.name": "example_server"])),
])
let resource = await resourceDetection.resource(environment: environment, logLevel: .trace)

// Bootstrap the metrics backend to export metrics periodically in OTLP/gRPC.
let registry = OTelMetricRegistry()
let metricsExporter = try OTLPGRPCMetricExporter(configuration: .init(environment: environment))
let metrics = OTelPeriodicExportingMetricsReader(
    resource: resource,
    producer: registry,
    exporter: metricsExporter,
    configuration: .init(
        environment: environment,
        exportInterval: .seconds(5) // NOTE: This is overridden for the example; the default is 60 seconds.
    )
)
MetricsSystem.bootstrap(OTLPMetricsFactory(registry: registry))

// Bootstrap the tracing backend to export traces periodically in OTLP/gRPC.
let processor = OTelBatchSpanProcessor(exporter: exporter, configuration: .init(environment: environment))
let exporter = try OTLPGRPCSpanExporter(configuration: .init(environment: environment))
let tracer = OTelTracer(
    idGenerator: OTelRandomIDGenerator(),
    sampler: OTelConstantSampler(isOn: true),
    propagator: OTelW3CPropagator(),
    processor: processor,
    environment: environment,
    resource: resource
)
InstrumentationSystem.bootstrap(tracer)

// Add the observability services to a service group with the adopter service(s) and run.
let serviceGroup = ServiceGroup(services: [metrics, tracer, server], logger: .init(label: "ServiceGroup"))
try await serviceGroup.run()
```

> [!note]
> The above snippet only uses a logging metadata provider. When Swift OTel is extended with an OTLP logging backend it would likely require a similarly verbose bootstrap with the current API design.

The current API has a number of usability drawbacks.

1. Adopters must discover and construct several objects, and chain them together, even if they just want the default
   behavior.
  
    Even if overloads were added to streamline the common case, because each of these objects is configured using its
    own initializer parameters, as soon as an adopter wishes to configure anything, they would need to revert to
    constructing and chaining the objects together.

2. A number of important configuration options are missing, including support for mTLS.

    Again, because each of these objects is configured using its own initializer parameters, adding support for new
    configuration options presents an API evolution challenge.

3. Adopters need to handle types with a public `run` method and/or conform to `Service`, but only a subset of these
   should be run by the adopter (others are run internally as part of the hierarchy).

4. Adopters using Swift Service Lifecycle are encouraged to run the background tasks in a specific order (usually logs,
   metrics, and traces), which adopters must discover from documentation and remember to do correctly.

5. There is asymmetry in which types provide the background tasks adopters must run: for tracing, adopters run the same
   type that is passed to `InstrumentationSystem.bootstrap()`; for metrics, adopters run an intermediate
   type, that is not passed to `MetricsSystem.bootstrap()`.

6. The existing API surface is also very broad, with an emphasis on extensibility. In addition to the many types that
   must be public (see (1)), all the abstractions are also public, and many types are generic over many of these
   abstractions. This presents discoverability challenges for adopters and evolution challenges for maintainers.

## Goals for the API

Partly informed by the above drawbacks, these are the proposed goals for the revised public API:

1. Adopters can bootstrap all observability backends with sensible defaults, with ~zero ceremony.

2. Adopters can configure and/or disable observability on a per-signal basis, in code.

   a. Adopters can configure supported features, according to the OTel spec, including:
      (i) Enabling (m)TLS for their exporters; and (ii) choosing between gRPC and HTTP exporters.

   b. Operators can configure and/or disable observability on a per-signal
      basis, using the environment variables defined in the OTel spec.

3. Adopters can compose the observability backends with other backends (e.g. multiplexing).

   Note: This does NOT mandate that the concrete types should public.

4. APIs should be Easy to Use and Hard to Misuse (EUHM). Some concrete examples of things to address in the current API:

    a. The public API surface should be as small as possible to achieve its goals, which will (i) improve
       discoverability; and (ii) reduce ambiguity.
    
    b. APIs should remove footguns; e.g. if an API returns something that can be passed to bootstrap, it should NOT have
       already been bootstrapped.

    c. Return types of APIs should only conform to `Service` and/or have a public `run()` method if the adopter is
       expected to run them.

    d. Furthermore, opaque return types could be used to provide an even clearer guide of what the user should do with
       the return type.
   
    e. If multiple background tasks are needed with a specific run order, they should be consolidated into a single
       return type that conforms to `Service` and/or has a public `run()` method, which takes care of the order.

5. The public API surface should be as minimal as possible to achieve the goals above.
   
    This will likely result in a reduced public API surface.

6. Adopters should be able to opt-out of exporter-specific package dependencies at compile-time (e.g. gRPC), using
   package traits.

## Proposed API

### Example: Bootstrap observability backends with ~zero ceremony

```swift
// Bootstrap observability backends and get a single, opaque service, to run.
let observability = try OTel.bootstrap()

// Run observability service(s) in a service group with adopter service(s).
let server = MockService(name: "AdopterServer")
let serviceGroup = ServiceGroup(services: [observability, server], logger: .init(label: "ServiceGroup"))
try await serviceGroup.run()
```

### Example: Configure observability backends

> Note: Some of the values used here are the defaults, but are explicitly set for the purpose of illustrating the API.

```swift
// Start with defaults.
var otelConfig = OTel.Configuration.default
// Configure traces with specific OTLP/gRPC endpoint, with mTLS, compression, and custom timeout.
otelConfig.traces.exporter = .otlp
otelConfig.traces.otlpExporter.endpoint = "https://otel-collector.example.com:4317"
otelConfig.traces.otlpExporter.protocol = .grpc
otelConfig.traces.otlpExporter.compression = .gzip
otelConfig.traces.otlpExporter.certificateFilePath = "/path/to/cert"
otelConfig.traces.otlpExporter.clientCertificateFilePath = "/path/to/cert"
otelConfig.traces.otlpExporter.clientKeyFilePath = "/path/to/key"
otelConfig.traces.otlpExporter.timeout = .seconds(3)
// Configure metrics with localhost OTLP/HTTP endpoint, without TLS, uncompressed, and different timeout.
otelConfig.metrics.exporter = .otlp
otelConfig.metrics.otlpExporter.endpoint = "http://localhost:4318"
otelConfig.metrics.otlpExporter.protocol = .httpProtobuf
otelConfig.metrics.otlpExporter.compression = .none
otelConfig.metrics.otlpExporter.timeout = .seconds(5)
// Disable logs entirely.
otelConfig.logs.enabled = false

// Bootstrap observability backends and still get a single, opaque service, to run.
let observability = try OTel.bootstrap(configuration: otelConfig)

// Run observability service(s) in a service group with adopter service(s).
let server = MockService(name: "AdopterServer")
let serviceGroup = ServiceGroup(services: [observability, server], logger: .init(label: "ServiceGroup"))
try await serviceGroup.run()
```

> [!important]
> `OTel.bootstrap` will apply additional configuration from the environment variables defined in the OTel spec.

### Example: Compose observability backends

```swift
// Create backends that have _not_ been bootstrapped.
let logging = try OTel.makeLoggingBackend(configuration: .default)
let metrics = try OTel.makeMetricsBackend(configuration: .default)
let tracing = try OTel.makeTracingBackend(configuration: .default)

// Compose backends as needed and bootstrap the observability subsystems manually.
LoggingSystem.bootstrap({ label in MultiplexLogHandler([logging.factory(label), SwiftLogNoOpLogHandler(label)]) })
MetricsSystem.bootstrap(MultiplexMetricsHandler(factories: [metrics.factory, NOOPMetricsHandler.instance]))
InstrumentationSystem.bootstrap(MultiplexInstrument([tracing.factory, NoOpTracer()]))

// Run observability service(s) in a service group with adopter service(s).
let server = MockService(name: "AdopterServer")
let serviceGroup = ServiceGroup(
    services: [logging.service, metrics.service, tracing.service, server],
    logger: .init(label: "ServiceGroup")
)
try await serviceGroup.run()
```

## Detailed design

### Bootstrap

The primary API is a single, static `OTel.bootstrap()` function, which uses an opaque return type that conforms to
`Service`, regardless of which observability signals are enabled.

```swift
extension OTel {
    public static func bootstrap(
        configuration: Configuration = .default
    ) throws -> some Service
}
```

### Make backends

For more advanced use cases, we offer APIs for constructing the backends to compose with other types in the Swift
observability ecosystem. These APIs all have a similar shape and return a tuple of two things:

- The factory: a value that could be passed directly to the observability subsystem bootstrap, e.g.
  `LoggingSystem.bootstrap(_:)`; and
- The service: a type that performs the background work required for the operation of the backend.

```swift
extension OTel {
    public static func makeLoggingBackend(
        configuration: OTel.Configuration = .default
    ) throws -> (factory: @Sendable (String) -> any Logging.LogHandler, service: some
    Service)

    public static func makeMetricsBackend(
        configuration: OTel.Configuration = .default
    ) throws -> (factory: any CoreMetrics.MetricsFactory, service: some Service)

    public static func makeTracingBackend(
        configuration: OTel.Configuration = .default
    ) throws -> (factory: any Tracing.Tracer, service: some Service)
}
```

### Configuration

Even though this proposed API is reducing visibility of the chain of types required for observability, the behavior of
those types should still be configurable. In fact, this proposal includes widening the configurable behavior compared to
the current API.

The OTel SDK specification defines which components should be configurable in code, and how configuration can be
specified with environment variables, including the hierarchy of per-signal and general configuration[^1].

The `bootstrap`, `makeLoggingBackend`, `makeMetricsBackend`, and `makeTracingBackend` APIs all take a configuration
parameter. This allows for top-level configuration, without the adopter needing to discover, construct, and configure
the implementation types that drive the backend.

The configuration is a nested value-type, rooted at `OTel.Configuration`, following the structure and defaults from the
OTel spec as closely as practical for the subset of features supported by Swift OTel.

To support API evolution, the configuration follows a default-and-mutate pattern and uses _enum-like_ structs for values
that would naturally be expressed with enums.

As discussed in the OTel specification, unknown or unsupported configuration values (e.g. from environment variables)
will be logged as a diagnostic and the default will be used.

The below snippet is a representative example of the _shape_ of `OTel.Configuration` and the earlier sections of this
document illustrate its use.

```swift
extension OTel {
    public struct Configuration: Sendable {
        public var serviceName: String
        public var resourceAttributes: [String: String]
        public var logger: LoggerSelection
        public var logLevel: LogLevel
        public var propagators: [Propagator]
        public var traces: TracesConfiguration
        public var metrics: MetricsConfiguration
        public var logs: LogsConfiguration

        public static let `default`: Self
    }
}

extension OTel.Configuration {
    public struct LoggerSelection {
        public static let console: Self
        public static func custom(_: Logging.Logger) -> Self
    }
}

extension OTel.Configuration {
    public struct LogLevel: Sendable {
        public static let error: Self
        public static let warning: Self
        public static let info: Self
        public static let debug: Self
    }
}

extension OTel.Configuration {
    public struct Propagator: Sendable {
        public static let traceContext: Self
        public static let baggage: Self
        public static let b3: Self
        public static let b3Multi: Self
        public static let jaeger: Self
        public static let xray: Self
        public static let otTrace: Self
        public static let none: Self
    }
}

extension OTel.Configuration {
    public struct TracesConfiguration: Sendable {
        public var enabled: Bool
        public var batchSpanProcessor: BatchSpanProcessorConfiguration
        public var exporter: ExporterSelection
        public var otlpExporter: OTLPExporterConfiguration

        public static let `default`: Self
    }

    public struct MetricsConfiguration: Sendable {
        public var enabled: Bool
        public var exportInterval: Duration
        public var exportTimeout: Duration
        public var exporter: ExporterSelection
        public var otlpExporter: OTLPExporterConfiguration

        public static let `default`: Self
    }

    public struct LogsConfiguration: Sendable {
        public var enabled: Bool
        public var exporter: ExporterSelection
        public var otlpExporter: OTLPExporterConfiguration

        public static let `default`: Self
    }
}

extension OTel.Configuration.TracesConfiguration {
    public struct BatchSpanProcessorConfiguration: Sendable {
        public var scheduleDelay: Duration
        public var exportTimeout: Duration
        public var maxQueueSize: Int
        public var maxExportBatchSize: Int

        public static let `default`: Self
    }
}

extension OTel.Configuration.TracesConfiguration {
    public struct ExporterSelection: Sendable {
        public static let otlp: Self
        public static let jaeger: Self
        public static let zipkin: Self
        public static let console: Self
    }
}

extension OTel.Configuration.MetricsConfiguration {
    public struct ExporterSelection: Sendable {
        public static let otlp: Self
        public static let prometheus: Self
        public static let console: Self
    }
}

extension OTel.Configuration.LogsConfiguration {
    public struct ExporterSelection: Sendable {
        public static let otlp: Self
        public static let console: Self
    }
}

extension OTel.Configuration {
    public struct OTLPExporterConfiguration: Sendable {
        public var endpoint: String
        public var insecure: Bool
        public var certificateFilePath: String?
        public var clientKeyFilePath: String?
        public var clientCertificateFilePath: String?
        public var headers: [(String, String)]
        public var compression: Compression
        public var timeout: Duration
        public var `protocol`: `Protocol`

        public static let `default`: Self
    }
}

extension OTel.Configuration.OTLPExporterConfiguration {
    public struct Compression: Sendable {
        public static let none: Self
        public static let gzip: Self
    }

    public struct `Protocol`: Equatable, Sendable {
        public static let grpc: Self
        public static let httpProtobuf: Self
        public static let httpJSON: Self
    }
}
```

### Reducing visibility of all other existing API

The existing API has biased toward a large public API. This includes all the concrete types that need chaining together
to construct a functional OTLP backend for each signal, but also a wide API surface for extensibility.

For example, the `OTelTracer` is generic over five abstractions: `OTelIDGenerator`, `OTelSampler`, `OTelPropagator`,
`OTelSpanProcessor`, and `Clock`, with public concrete types (sometimes several) for each.

Similarly, there is a public abstraction for populating attributes, `OTelResourceDetector`, with several public
implementations and helper types: `OTelResource`, `OTelResourceDetection`, `OTelEnvironment`,
`OTelProcessResourceDetector`, `OTelManualResourceDetector`, and `OTelEnvironmentResourceDetector`.

The primary goal of Swift OTel is to provide OTLP backends for the Swift observability APIs and, where appropriate,
support configuring the behavior according to the OTel specification.

Therefore, we propose to make all the existing API not expressly discussed in the above bootstrap, backends, and
configuration sections, internal.

Reducing the API surface to just that which is required to meet these goals paves an easier path for a 1.0 release, and
does not rule out expanding it the future to support deeper customization.

Where extensibility is required, adopters should compose the opaque backends with their own logic. As a concrete
example, if an adopter wishes to pre-sample traces in a way that is not supported in the OTel specification, they should
construct their own wrapper type that conforms to `Tracing.Tracer`, which wraps the backend returned by
`OTel.makeTracingBackend`.

### Package structure and traits

Swift OTel will provide a single library product, `OTel`, with the public API discussed above.

Any other existing library products will become internal targets. Concretely, the majority of the existing `OTel`
library product will move to an internal `OTelCore` target; and `OTLPGRPC` will be made an internal detail.

Support for OTLP/gRPC and OTLP/HTTP will be gated behind package traits: `OTLPGRPC` and `OTLPHTTP`, respectively, which
will both be enabled by default. This allows adopters to only include the dependencies for a single exporter.

Swift OTel might opt to make the corresponding configuration values only reachable in code with the trait enabled, e.g.:

```swift
var config = OTel.Configuration.default
config.traces.otlp.protocol = .grpc  // compiler error: Using the OTLP/GRPC exporter requires the `OTLPGRPC` trait enabled.
```

Attempting to use these configuration values using their corresponding environment variable values will result in a
runtime error, e.g.:

```swift
// Assuming OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=grpc, then...
try OTel.bootstrap()  // runtime error: Using the OTLP/GRPC exporter requires the `OTLPGRPC` trait enabled.
```

### Logging within Swift OTel

There has been some historic confusion related to logging within the Swift OTel library itself, which stems from:

1. Swift Log's process-wide, one-shot bootstrap mechanism for logging; and
2. Swift OTel providing an OTLP logging backend.

At first glance this presents a chicken-and-egg problem: Do Swift OTel's own logs go to OTLP? What about pre-bootstrap
logging? Where do errors about exporting logs, get logged? Or the handling of unsupported configuration values?

These concerns are addressed by the OTel spec, which states that such "self-diagnostics" can be handled with any
language-specific conventions and/or callbacks[^2].

Swift OTel will handle this by having its own `Logger`, which will log to standard error by default, and can be configured during bootstrap.

## Incorporated feedback

This section consolidates the feedback that was received during the review period which has been accepted and
incorporated into the current proposal.

### Model resource attributes configuration as a dictionary

The original proposal used an array of tuples for the resource attribute configuration:

```swift
public var OTel.Configuration.resourceAttributes: [(String, String)]
```

The OTel spec details how attribute collections must use unique keys but is flexible on how these are expressed in an
SDK. It specifically calls out that APIs will have to deal with deduplication and that repeated keys will need to be
handled as a result of supporting the W3C Baggage format, when specified using an environment variable.

> *Attribute Collections*
>
> Resources, Instrumentation Scopes, Metric points, Spans, Span Events, Span Links and Log Records may contain
> a collection of attributes. The keys in each such collection are unique, i.e. there MUST NOT exist more than one
> key-value pair with the same key. The enforcement of uniqueness may be performed in a variety of ways as it best fits
> the limitations of the particular implementation.
>
> Normally for the telemetry generated using OpenTelemetry SDKs the attribute key-value pairs are set via an API that
> either accepts a single key-value pair or a collection of key-value pairs. Setting an attribute with the same key as
> an existing attribute SHOULD overwrite the existing attribute’s value. See for example Span’s SetAttribute API.
>
> — source: https://opentelemetry.io/docs/specs/otel/common/#attribute-collections

> The `OTEL_RESOURCE_ATTRIBUTES` environment variable will contain of a list of key value pairs, and these are expected
> to be represented in a format matching to the W3C Baggage, except that additional semi-colon delimited metadata is not
> supported, i.e.: `key1=value1,key2=value2`.
>
> — source: https://opentelemetry.io/docs/specs/otel/resource/sdk/#specifying-resource-information-via-an-environment-variable

During review it was suggested that we model this as a dictionary to more clearly express the unique key semantics.

This feedback was incorporated and the current proposal includes the following API:

```swift
public var OTel.Configuration.resourceAttributes: [String: String]
```

### Support custom logger for internal logging

For the initial 1.0 release, the proposal is to follow the OTel specification for the scope and spelling of
configuration. This is limited to configuring the logging level used by the internal logger used by the SDK itself
(note: this is unrelated to the logging backend). How these internal logs were emitted was an implementation detail.

During review, we received a request to inject a custom logger for the internal logging. Because these logs will provide
information critical to debugging issues with observability, we decided to incorporate this feedback and the current
proposal now supports providing a logger in the configuration.

### Defer APIs for disabling environment variable config

In order to support the requirements of operators, the bootstrap APIs in the original proposal included
a `detectEnvironmentOverrides: Bool = true` parameter.

This sparked some discussion during the review regarding the default precedence of in-code and environment variable
configuration, and whether the API should support disabling and/or configuring the precedence of environment variable
configuration.

A number of desired semantics and alternative spellings are being discussed and so we decided to defer explicit API for
this.

The parameter has been removed and the library will unconditionally support environment variable overrides for
operators.

A future version may add API for disabling and/or configuring the precedence of environment variable configuration.

## Future directions

This section consolidates feedback that was received during the review period, which has been considered out of scope
for 1.0, but could be incorporated in a future version.

### Resource detection

The pre-1.0 API included some support for "resource detection" to automatically populate some resource
attributes with e.g. process information, environment details, and service name. The current proposal intentionally
omits built-in resource detection for several reasons:

- Limited stable specification: Most resource detection semantics in the OTel spec are not yet marked as stable, with
  only `service.name` being both required and stable.

- Specification guidance: The OTel spec states that custom resource detectors "MUST be implemented as packages separate
  from the SDK."

Resource attributes can still be manually configured with the proposed API via `OTel.Configuration.serviceName` and
`OTel.Configuration.resourceAttributes`, both in-code and via environment variables, which aligns with the OTel spec.

This does not preclude extending the API in the future to support some automatic resource detection, which would likely
be built on the configuration API, to maintain the simple bootstrap APIs:

```swift
// Future API possibility
var config = OTel.Configuration.default
await config.applyingResourceAttributes(from: someDetector)
let observability = try OTel.bootstrap(configuration: config)
```

### Extending configuration beyond the OTel spec

For the initial 1.0 release, the proposal is to closely follow the OTel specification for the scope and spelling of
configuration.

This is a baseline and does not preclude future versions supporting additive configuration API.

### More extensible (m)TLS configuration

The current proposal follows the OTel specification for the scope and spelling of configuration. This is limited to
configuring the file paths to certificate and keys used for (m)TLS.

A future release might include additive API for more expressive configuration, e.g. custom callbacks for advanced use
cases, using types from Swift Certificates, or support for certificate reloading.

### Configurable transports for the OTLP exporter

The current proposal follows the OTel specification for the scope and spelling of configuration. This is limited to
choosing between OTLP/gRPC, OTLP/HTTP+Protobuf, and OTLP/HTTP+JSON, with the underlying gRPC and HTTP client libraries
being an implementation detail.

A future release could include additive API for for more expressive configuration, e.g. offering a URLSession-based
OTLP/HTTP transport for adopters running on Darwin platforms.

Another possibility would be to offer an extensible API, allowing adopters to provide a custom transport implementation,
likely defined in terms of Swift HTTP Types.

## Alternatives considered

This section consolidates feedback that was received during the review period, which has been considered out of scope
because they are incompatible with the proposed API or conflict with stated goals of the package.

### Enums with associated values in configuration

An alternative approach for exporter configuration would be to use enum associated values for exporter-specific
configuration:

```swift
// Alternative approach with associated values
public enum ExporterSelection {
    case otlp(OTLPExporterConfiguration)
    case console
}
```

This proposal does not do this for the following reasons:

-  Ergonomic configuration: When starting with defaults and making incremental changes, associated values
   require switching on a configuration field, extracting the associated value, modifying its nested configuration, and
   then replacing the enum value. The proposed API supports updating just the desired nested properties.

- Runtime composition: The proposed configuration API is designed to compose with environment variable
   overrides set by operators, where OTLP configuration should be applied _if_ the OTLP exporter is selected, regardless
   of whether that selection was made.

- Specification guidance: The chosen structure mirrors the configuration hierarchy defined in the OTel spec.

### Reducing the set of default enabled package traits

This proposal uses traits to guard the provision of both the HTTP and gRPC exporters. This allows adopters to reduce
their build times if they want to explicitly remove support for one of the exporters.

Disabling the `OTLPGRPC` trait by default was considered but was rejected in favour of:

- Ease of use, out of the box.

- Support for runtime configuration by operators without manual steps on by the developer.

### Moving Swift Service Lifecycle dependency behind a trait

The current proposal places the dependencies used for the OTLP/gRPC and OTLP/HTTP exporters behind traits to streamline
adopters transitive dependencies and build times.

During the review period there was a question about moving the Swift Service Lifecycle dependency behind a trait. We did
not incorporate this feedback because (1) the Swift Service Lifecycle is a small, and more crucially, (2) it is an
important part of the implementation of Swift OTel, not just the API surface.

### Removing top-level `OTel` namespace

The current proposal nests the APIs under an `OTel` namespace.

During review we discussed whether this was necessary and whether using a namespace that matches the module name would
cause issues.

This feedback was not incorporated for a few reasons:

1. The API is surface is mostly static functions, and we'd prefer to not
   pollute the global namespace.
2. It provides a single point of discoverability for the APIs.
3. It provides a place to anchor top-level docs (almost module-level docs) that are accessible in code, which otherwise
   need to be viewed in the hosted DocC article.
4. Any issues resulting from the use of the same name for the top-level enum and the module, are historical, and have
   been addressed.

   The concrete concern is if an adopter takes a new dependency on this package but already has a type called `OTel` in
   their codebase. If they cannot rename this type (e.g. because it forms part of the adopter's API surface) then this
   is mitigated by using a module alias when adding the dependency.

   Furthermore, the import of this module is likely to be isolated to a single place in an adopter codebase, where they
   bootstrap the observability backends, which reduces the risk of any such clash.

[^1]: Configuration in the OTel specification:
    - https://opentelemetry.io/docs/languages/sdk-configuration/general/
    - https://opentelemetry.io/docs/languages/sdk-configuration/otlp-exporter/
    - https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
    - https://opentelemetry.io/docs/specs/otel/protocol/exporter/#configuration-options

[^2]: https://opentelemetry.io/docs/specs/otel/error-handling/#self-diagnostics

# Resource Detection

Detect attributes describing the entity being instrumented.

@Metadata {
    @Available("Swift OTel", introduced: "1.0")
}

## Overview

A resource is a set of attributes describing the entity being instrumented, e.g. a service in a distributed system.
Resources are obtained using resource detection, which encapsulates different ways of detecting resource attributes,
like inspecting environment variables, the current process, a Docker container etc.

Resource detection is **the first piece to be run** when using Swift OTel, because other components like ``OTelTracer``
rely on the detected resource.

Swift OTel uses the ``OTelResourceDetector`` to represent a single way of detecting resource attributes,
and ``OTelResourceDetection`` to facilitate running one or more resource detectors.

> Important: Resource detectors are asynchronous to allow making network calls, but should complete as fast as possible
> to not delay the start time of your system significantly. You may use the ``OTelResourceDetection/timeout`` parameter
> to set a custom timeout after which detection is cancelled.

### Built-in resource detectors

The library ships with a set of built-in resource detectors:

@Links(visualStyle: list) {
    - ``OTelEnvironmentResourceDetector``
    - ``OTelProcessResourceDetector``
    - ``OTelResourceDetector/manual(_:)``
}

### Running resource detection

Before configuring the other parts of Swift OTel, run resource detection by creating an instance of
``OTelResourceDetection`` and calling its ``OTelResourceDetection/resource(environment:logLevel:)`` method:

```swift
let environment = OTelEnvironment.detected()
let resourceDetection = OTelResourceDetection(detectors: [
    OTelProcessResourceDetector(),
    OTelEnvironmentResourceDetector(environment: environment),
])

let resource = await resourceDetection.resource(environment: environment, logLevel: .trace)

// ... pass the resource to other Swift OTel components
```

### Implementing a custom resource detector

Creating your own resource detector is as easy as conforming to ``OTelResourceDetector``. Here's an example
implementation that reads a single attribute from an environment variable:

```swift
struct MyResourceDetector: OTelResourceDetector {
    private let environment: OTelEnvironment

    init(environment: OTelEnvironment) {
        self.environment = environment
    }

    func resource() async throws -> OTelResource {
        if let value = environment["MY_VARIABLE"] {
            return OTelResource(attributes: ["my_attribute": "\(value)"])
        } else {
            return OTelResource()
        }
    }
}
```

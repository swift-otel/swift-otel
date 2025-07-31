# Counter

@Metadata {
    @PageKind(sampleCode)
    @CallToAction(purpose: link, url: "https://github.com/swift-otel/swift-otel/blob/main/Examples/Counter")
    @Available("Swift", introduced: 5.9)
}

A service that infinitely increments a counter with randomized delays, instrumented using Swift OTel.

## Overview

Each increment to the counter is instrumented by a span, as shown in the screenshot below.

@Image(source: "jaeger", alt: "A screenshot of Jaeger showing spans recorded for this example.") {
    [Jaeger](https://jaegertracing.io) displaying the spans recorded for this example. 
}

In addition to the exported spans, the example also logs every time the count is incremented. These log
statements automatically include the trace/span ID of the current span via the
``Logging/Logger/MetadataProvider/otel`` Logging `MetadataProvider`:

```sh
2023-11-24T12:00:29+0100 info Counter : count=262 span-id=41d259b120114123 trace-id=08536b458fb95482a59fa15ee185fcaf [Example] Counted up.
```

### Simulated failures

Every 10th increment, the service simulates a failure that is reflected in the trace.
The example also logs these failures, making it easy to look up the trace associated with the failure:

```sh
2023-11-24T12:00:28+0100 error Counter : span-id=ce3e5c9549dca1cf trace-id=c0270967c8f364fc7e0762f107e967a3 value=260 [Example] Failed to count up, skipping value.
```

## Running the example

To run the example locally, you need two prerequisites:

- [Docker](https://docker.com)
- [Swift 5.9 (or above)](https://swift.org/download)

First, spin up Jaeger via docker compose:

```sh
docker compose up -d
```

Then, run the `example` executable to start counting:

```sh
swift run example
```

To stop counting, press `CTRL + C`, gracefully shutting down the service.

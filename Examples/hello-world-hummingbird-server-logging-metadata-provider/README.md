# Hello World HTTP server with OTel logging metadata provider

An HTTP server that uses middleware to emit telemetry for each HTTP request.

> **Disclaimer:** This example is deliberately simplified and is intended for illustrative purposes only.

## Overview

This example bootstraps only the tracing Swift subsystems to export
traces to Jaeger, via an OTel Collector. The logging and metrics backends are
disabled. It then bootstraps a standard error logger using the Swift OTel logging
metadata provider, which includes the span and trace ID for the current span in
the structured logging metadata.

It then starts a Hummingbird HTTP server along with its associated middleware for instrumentation.

Traces are exported using OTLP/HTTP+Protobuf. Logs are exported to standard error.

## Notable Configuration

```swift
config.logs.enabled = false
config.metrics.enabled = false
...
LoggingSystem.bootstrap(
    StreamLogHandler.standardError(label:metadataProvider:),
    metadataProvider: OTel.makeLoggingMetadataProvider()
)
```

## Testing

The example uses [Docker Compose](https://docs.docker.com/compose) to run a set of containers to collect and
visualize the telemetry from the server, which is running on your local machine.

```none
┌──────────────────────────────────────────────────────────────────────┐
│                                                                  Host│
│                       ┌────────────────────────────────────────────┐ │
│                       │                              Docker Compose│ │
│        ┌────────────┐ │ ┌───────────┐                              │ │
│     ┌─▶│   stderr   │ │ │           │                              │ │
│     │  └────────────┘ │ │           │                              │ │
│ Logs│                 │ │           │                              │ │
│     │                 │ │           │   Traces      ┌────────────┐ │ │
│ ┌───┴────┐            │ │   OTel    ├──────────────▶│   Jaeger   │ │ │
│ │        │            │ │ Collector │               └────────────┘ │ │
│ │  HTTP  │            │ │           │                              │ │
│ │ Server │────────────┼▶│           │                              │ │
│ │        │            │ │           │                              │ │
│ └────────┘            │ │           │   Debug       ┌────────────┐ │ │
│      ▲      ┌──────┐  │ │           ├──────────────▶│   stderr   │ │ │
│      └──────│ curl │  │ └───────────┘               └────────────┘ │ │
│  GET /hello └──────┘  └────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

The server sends requests to OTel Collector, which is configured with an OTLP receiver for traces;
and an exporter for Jaeger. The Collector is also
configured with a debug exporter so we can see the events it receives in the container logs.

### Running the collector and visualization containers

In one terminal window, run the following command:

```console
% docker compose -f docker/docker-compose.yaml up
[+] Running 2/2
 ✔ Container docker-jaeger-1          Created                       0.5s
 ✔ Container docker-otel-collector-1  Created                       0.5s
...
```

At this point the tracing collector and visualization tools are running.

### Running the server

Now, in another terminal, run the server locally using the following command:

```console
% swift run
```

### Making some requests

Finally, in a third terminal, make a few requests to the server:

```console
% for i in {1..5}; do curl localhost:8080/hello; done
hello
hello
hello
hello
hello
```

### Viewing the logs

In the terminal where the Swift server is running, you should see the logging output from the standard error logger.
Logs related to HTTP requests have the span and trace ID inclueded in the structured logging metadata automatically:

```console
2025-07-28T20:34:54+0100 info Hummingbird : [HummingbirdCore] Server started and listening on 127.0.0.1:8080
2025-07-28T20:35:04+0100 info Hummingbird : hb.request.id=3c0e940f183620ad41e5690bded6b48 hb.request.method=GET hb.request.path=/hello span_id=eb674e50dd49e7d3 trace_flags=1 trace_id=e378e2d400c17feab82671124e13f2f6 [Hummingbird] Request
```

In the output from the OTel Collector, you should see debug messages for the received OTLP events.

### Visualizing the traces using Jaeger UI

Visit Jaeger UI in your browser at [localhost:16686](http://localhost:16686).

Select `hello_world` from the dropdown and click `Find Traces`, or use
[this pre-canned link](http://localhost:16686/search?service=hello_world).

See the traces for the recent requests and click to select a trace for a given request.

Click to expand the trace, the metadata associated with the request and the
process, and the events.

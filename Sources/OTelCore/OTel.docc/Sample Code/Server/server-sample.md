# Server

@Metadata {
    @PageKind(sampleCode)
    @CallToAction(purpose: link, url: "https://github.com/swift-otel/swift-otel/blob/main/Examples/Counter")
    @Available("Swift", introduced: 5.9)
}

An HTTP server that uses middleware to emit traces and metrics for each HTTP request.

## Overview

This example package configures and starts a Hummingbird HTTP server along with
its associated middleware for instrumentation.

## Testing

The example uses [Compose](https://docs.docker.com/compose) to run a set of
containers to collect and visualize the traces from the server, which is
running on your local machine.

```none
┌──────────────────────────────────────────────────────────────────────┐
│                                                                  Host│
│                       ┌────────────────────────────────────────────┐ │
│                       │                              Docker Compose│ │
│                       │ ┌───────────┐                              │ │
│                       │ │           │  OTLP/gRPC    ┌────────────┐ │ │
│ ┌────────┐            │ │           │──────────────▶│   Jaeger   │ │ │
│ │        │            │ │           │               └────────────┘ │ │
│ │  HTTP  │ OTLP/gRPC  │ │   OTel    │ GET /metrics  ┌────────────┐ │ │
│ │ server │────────────┼▶│ Collector │◀──────────────│ Prometheus │ │ │
│ │        │            │ │           │               └────────────┘ │ │
│ └────────┘            │ │           │  Debug logs   ┌────────────┐ │ │
│      ▲      ┌──────┐  │ │           │──────────────▶│   stderr   │ │ │
│      └──────│ curl │  │ └───────────┘               └────────────┘ │ │
│  GET /hello └──────┘  └────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

The server sends requests to OTel Collector, which is configured with an OTLP
receiver and a Jaeger exporter. The Collector is also configured with a debug
exporter so we can see the events it receives in the container logs.

### Running the collector and visualization containers

In one terminal window, run the following command:

```console
% docker compose -f docker/docker-compose.yaml up
[+] Running 3/3
 ✔ Container docker-jaeger-1          Created                       0.5s
 ✔ Container docker-prometheus-1      Created                       0.4s
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

You should see log messages from the server for each request and each log line
should include an OTel `trace_id` field.

### Visualizing the traces using Jaeger UI

Visit Jaeger UI in your browser at [localhost:16686](http://localhost:16686).

Select `example_server` from the dropdown and click `Find Traces`, or use
[this pre-canned link](http://localhost:16686/search?service=example_server).

See the traces for the recent requests and click to select a trace for a given request.

Click to expand the trace, the metadata associated with the request and the
process, and the events.

### Visualizing the metrics using Prometheus UI

Now open the Prometheus UI in your web browser by visiting
[localhost:9090](http://localhost:9090). Click the graph tab and update the
query to `hb_request_duration_bucket`, or use [this pre-canned
link](http://localhost:9090/graph?g0.expr=hb_request_duration_bucket).

You should see the graph showing the recent request durations.

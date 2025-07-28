# Hello World HTTP server with observability middleware (OTLP/gRPC)

An HTTP server that uses middleware to emit telemetry for each HTTP request.

> **Disclaimer:** This example is deliberately simplified and is intended for illustrative purposes only.

## Overview

This example bootstraps the logging, metrics, and tracing Swift subsystems to export
logs, metrics, and traces to file, Prometheus, and Jaeger, respectively, via an OTel Collector.

It then starts a Hummingbird HTTP server along with its associated middleware for instrumentation.

Telemetry data is exported using OTLP/gRPC.

## Notable Configuration

```swift
// Configure the exporters to use OTLP/gRPC.
config.logs.otlpExporter.protocol = .grpc
config.metrics.otlpExporter.protocol = .grpc
config.traces.otlpExporter.protocol = .grpc
```

## Testing

The example uses [Docker Compose](https://docs.docker.com/compose) to run a set of containers to collect and
visualize the telemetry from the server, which is running on your local machine.

```none
┌──────────────────────────────────────────────────────────────────────┐
│                                                                  Host│
│                       ┌────────────────────────────────────────────┐ │
│                       │                              Docker Compose│ │
│                       │ ┌───────────┐                              │ │
│                       │ │           │   Logs        ┌────────────┐ │ │
│                       │ │           ├──────────────▶│    File    │ │ │
│                       │ │           │               └────────────┘ │ │
│                       │ │           │   Traces      ┌────────────┐ │ │
│ ┌────────┐            │ │   OTel    ├──────────────▶│   Jaeger   │ │ │
│ │        │            │ │ Collector │               └────────────┘ │ │
│ │  HTTP  │            │ │           │   Metrics     ┌────────────┐ │ │
│ │ Server │────────────┼▶│           │◀──────────────│ Prometheus │ │ │
│ │        │            │ │           │               └────────────┘ │ │
│ └────────┘            │ │           │   Debug       ┌────────────┐ │ │
│      ▲      ┌──────┐  │ │           ├──────────────▶│   stderr   │ │ │
│      └──────│ curl │  │ └───────────┘               └────────────┘ │ │
│  GET /hello └──────┘  └────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

The server sends requests to OTel Collector, which is configured with an OTLP receiver for logs, metrics, and traces;
and exporters for Jaeger, Prometheus and file for traces, metrics, and logs, respectively. The Collector is also
configured with a debug exporter so we can see the events it receives in the container logs.

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

In the output from the OTel Collector, you should see debug messages for the received OTLP events.

### Viewing the log records

The file the OTel Collector is using to export log records is mounted from the host. In another terminal window, you can
watch the logging output using the following command:

```console
% tail -f docker/logs/logs.json
{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"hello_world"}}]},"scopeLogs":[{"scope":{"name":"swift-otel","version":"1.0.0"},"logRecords":[{"timeUnixNano":"1753456690834655000","observedTimeUnixNano":"1753456690834655000","severityNumber":9,"severityText":"info","body":{"stringValue":"Server started and listening on 127.0.0.1:8080"},"attributes":[{"key":"code.lineno","value":{"stringValue":"248"}},{"key":"code.filepath","value":{"stringValue":"HummingbirdCore/Server.swift"}},{"key":"code.function","value":{"stringValue":"makeServer(childChannelSetup:configuration:)"}}],"traceId":"","spanId":""}]}]}]}
{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"hello_world"}}]},"scopeLogs":[{"scope":{"name":"swift-otel","version":"1.0.0"},"logRecords":[{"timeUnixNano":"1753456763244635000","observedTimeUnixNano":"1753456763244635000","severityNumber":9,"severityText":"info","body":{"stringValue":"Request"},"attributes":[{"key":"hb.request.method","value":{"stringValue":"GET"}},{"key":"hb.request.id","value":{"stringValue":"e6eb95ccb69ab50d09d765c003698d6a"}},{"key":"hb.request.path","value":{"stringValue":"/hello"}},{"key":"code.filepath","value":{"stringValue":"Hummingbird/LogRequestMiddleware.swift"}},{"key":"code.function","value":{"stringValue":"handle(_:context:next:)"}},{"key":"code.lineno","value":{"stringValue":"77"}}],"traceId":"74fbd693be58e132ca2423d87ea12837","spanId":"38fc1cc9d6517fc4"}]}]}]}
...
```

### Visualizing the metrics using Prometheus UI

Now open the Prometheus UI in your web browser by visiting
[localhost:9090](http://localhost:9090). Click the graph tab and update the
query to `http_server_request_duration_bucket`, or use [this pre-canned
link](http://localhost:9090/graph?g0.expr=http_server_request_duration_bucket).

You should see the graph showing the recent request durations.

### Visualizing the traces using Jaeger UI

Visit Jaeger UI in your browser at [localhost:16686](http://localhost:16686).

Select `hello_world` from the dropdown and click `Find Traces`, or use
[this pre-canned link](http://localhost:16686/search?service=hello_world).

See the traces for the recent requests and click to select a trace for a given request.

Click to expand the trace, the metadata associated with the request and the
process, and the events.

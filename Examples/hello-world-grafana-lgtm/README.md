# Hello World HTTP server with a local Grafana LGTM deployment

An HTTP server that uses middleware to emit telemetry for each HTTP request.

Local collector is the [Grafana LGTM](https://github.com/grafana/docker-otel-lgtm) package, containing support for logs, metrics, and distributed tracing in a single container.

> **Disclaimer:** This example is deliberately simplified and is intended for illustrative purposes only.

## Overview

This example bootstraps the logging, metrics, and tracing Swift subsystems to export
logs, metrics, and traces to a local Grafana instance.

It then starts a Hummingbird HTTP server along with its associated middleware for instrumentation.

Telemetry data is exported using OTLP/gRPC.

## Package traits

This example package depends on Swift OTel with only the `OTLPGRPC` trait enabled.

This is not strictly necessary because the default traits include both `OTLPHTTP` and `OTLPGRPC`, but it will reduce
 the dependency graph with a new enough Swift toolchain.

To use the OTLP/HTTP exporter, enable the `OTLPHTTP` trait or remove the `traits:` parameter on the package dependency.

## Notable Configuration

```swift
// Configure the exporters to use OTLP/gRPC.
config.logs.otlpExporter.protocol = .grpc
config.metrics.otlpExporter.protocol = .grpc
config.traces.otlpExporter.protocol = .grpc
```

## Testing

The example uses [Docker Compose](https://docs.docker.com/compose) to run a single container to collect and
visualize the telemetry from the server, which is running on your local machine.

```none
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                       Host  │
│                              ┌──────────────────────────────────────────────────────────┐   │
│                              │                                          Docker Compose  │   │
│                              │   ┌──────────────────────────────────────────────────┐   │   │
│                              │   │                                    Grafana LGTM  │   │   │
│                              │   │                                                  │   │   │
│                              │   │  ┌─────────────┐                                 │   │   │
│                              │   │  │             │                                 │   │   │
│                              │   │  │             │   Logs        ┌─────────────┐   │   │   │
│ ┌────────────┐               │   │  │             ├──────────────▶│    Loki     │   │   │   │
│ │            │               │   │  │             │               └─────────────┘   │   │   │
│ │            │               │   │  │             │   Metrics     ┌─────────────┐   │   │   │
│ │    HTTP    │               │   │  │    OTel     ├──────────────▶│  Prometheus │   │   │   │
│ │   Server   │───────────────┼───┼─▶│  Collector  │               └─────────────┘   │   │   │
│ │            │               │   │  │             │   Traces      ┌─────────────┐   │   │   │
│ │            │               │   │  │             ├──────────────▶│    Tempo    │   │   │   │
│ └────────────┘               │   │  │             │               └─────────────┘   │   │   │
│        ▲                     │   │  │             │                                 │   │   │
│        │                     │   │  │             │                                 │   │   │
│        │                     │   │  └─────────────┘                                 │   │   │
│        │        ┌──────┐     │   └──────────────────────────────────────────────────┘   │   │
│        └────────│ curl │     │                                                          │   │
│    GET /hello   └──────┘     └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

The server sends requests to Grafana LGTM, which internally runs OTel Collector, which in turn is configured with an OTLP receiver for logs, metrics, and traces; and exporters for Loki, Prometheus, and Tempo for logs, metrics, and traces, respectively.

### Running the collector and visualization containers

In one terminal window, run the following command:

```console
% docker compose -f docker/docker-compose.yaml up
[+] Running 1/1
 ✔ Container docker-grafana-1          Created                       0.5s
...
docker-grafana-1  | Running Grafana v12.0.2 logging=false
docker-grafana-1  | Running OpenTelemetry Collector v0.130.0 logging=false
docker-grafana-1  | Running Prometheus v3.5.0 logging=false
docker-grafana-1  | Waiting for the OpenTelemetry collector and the Grafana LGTM stack to start up...
docker-grafana-1  | Running Tempo v2.8.1 logging=false
docker-grafana-1  | Running Loki v3.5.2 logging=false
docker-grafana-1  | Running Pyroscope v1.14.0 logging=false
docker-grafana-1  | Prometheus is up and running. Startup time: 2 seconds
docker-grafana-1  | Otelcol is up and running. Startup time: 2 seconds
docker-grafana-1  | Pyroscope is up and running. Startup time: 3 seconds
docker-grafana-1  | Loki is up and running. Startup time: 3 seconds
docker-grafana-1  | Tempo is up and running. Startup time: 3 seconds
docker-grafana-1  | Grafana is up and running. Startup time: 7 seconds
docker-grafana-1  | Total startup time: 7 seconds
docker-grafana-1  | 
docker-grafana-1  | Startup Time Summary:
docker-grafana-1  | ---------------------
docker-grafana-1  | Grafana: 7 seconds
docker-grafana-1  | Loki: 3 seconds
docker-grafana-1  | Prometheus: 2 seconds
docker-grafana-1  | Tempo: 3 seconds
docker-grafana-1  | Pyroscope: 3 seconds
docker-grafana-1  | OpenTelemetry collector: 2 seconds
docker-grafana-1  | Total: 7 seconds
docker-grafana-1  | The OpenTelemetry collector and the Grafana LGTM stack are up and running. (created /tmp/ready)
docker-grafana-1  | Open ports:
docker-grafana-1  |  - 4317: OpenTelemetry GRPC endpoint
docker-grafana-1  |  - 4318: OpenTelemetry HTTP endpoint
docker-grafana-1  |  - 3000: Grafana. User: admin, password: admin
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

### Viewing logs, metrics, and traces

Open the local Grafana viewer at `http://localhost:3000` and in the left bar, click on Drilldown.

There, under Logs, Metrics, and Traces, you can browse the telemetry coming from the local test server as you run local requests.

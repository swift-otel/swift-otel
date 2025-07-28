# Swift OTel examples

See how to use and integrate Swift OTel with the wider ecosystem of packages and tools.

> Important: Many of these examples have been deliberately simplified and are intended for illustrative purposes only.

Each subdirectory contains a standalone example package, with a dedicated README, explaining how to build and run the
example.

## Getting started

Each of these examples bootstraps the logging, metrics, and tracing Swift subsystems and uses Docker Compose to export
logs, metrics, and traces to file, Prometheus, and Jaeger, respectively, via an OTel Collector.

- [hello-world-hummingbird-server-otlp-http-protobuf](./hello-world-hummingbird-server-otlp-http-protobuf) - HTTP server
  with instrumentation middleware, exporting telemetry over OTLP/HTTP+Protobuf.
- TODO: same as above but using OTLP/HTTP+json exporter
- TODO: same as above but using OTLP/gRPC exporter

## Advanced configuration

- TODO: Using (m)TLS
- TODO: Bootstrapping a subset of backends
- TODO: Using logging metadata provider

## Pruning dependencies with traits

- TODO: example building without the OTLPGRPC trait
- TODO: example building without the OTLPHTTP trait

## Integrations

- TODO: Vapor example
- TODO: Grafana example

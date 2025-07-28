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
- [hello-world-hummingbird-server-otlp-http-json](./hello-world-hummingbird-server-otlp-http-json) - HTTP server
  with instrumentation middleware, exporting telemetry over OTLP/HTTP+json.
- [hello-world-hummingbird-server-otlp-grpc](./hello-world-hummingbird-server-otlp-grpc) - HTTP server
  with instrumentation middleware, exporting telemetry over OTLP/gRPC.

## Advanced configuration

- [hello-world-hummingbird-server-tls](./hello-world-hummingbird-server-tls) - HTTP server
  with instrumentation middleware, exporting telemetry over OTLP/HTTP with TLS.
- [hello-world-hummingbird-server-mtls](./hello-world-hummingbird-server-mtls) - HTTP server
  with instrumentation middleware, exporting telemetry over OTLP/HTTP with mTLS.
- TODO: Bootstrapping a subset of backends
  with instrumentation middleware, with metrics and logging backends disabled.
- [hello-world-hummingbird-server-logging-metadata-provider](./hello-world-hummingbird-server-logging-metadata-provider) - HTTP server
  with instrumentation middleware, using logging metadata provider with separate logging backend.

## Pruning dependencies with traits

- TODO: example building without the OTLPGRPC trait
- TODO: example building without the OTLPHTTP trait

## Integrations

- TODO: Vapor example
- TODO: Grafana example

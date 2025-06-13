# Distributed Tracing

@Metadata {
    @TitleHeading("Signal")
    @PageImage(purpose: card, source: "tracing-card", alt: "An illustration of a distributed trace.")
    @Available("Swift OTel", introduced: "1.0")
}

OpenTelemetry tracing implemented on top of Swift Distributed Tracing.

## Overview

Distributed tracing support in Swift OTel is implemented on top of the
[Swift Distributed Tracing](https://github.com/apple/swift-distributed-tracing) library.
This allows "plug-and-play" like integration with other libraries from the ecosystem, e.g. 
[Hummingbird](https://github.com/hummingbird-project/hummingbird).
As long as they support `swift-distributed-tracing`, you'll be able to use their tracing capabilities with Swift OTel.

@Image(source: "tracing-card", alt: "An illustration of a distributed trace.") {
    A distributed trace, comprised of multiple spans across two services.
}

## Tracer

At the core of Distributed Tracing in Swift OTel is ``OTelTracer``. It's an implementation of the 
[`Tracer`](https://swiftpackageindex.com/apple/swift-distributed-tracing/1.0.1/documentation/tracing/tracer) protocol 
from `swift-distributed-tracing`.

You'll have **one `OTelTracer` instance per executable**, bootstrapped as the global tracer using the 
[`InstrumentationSystem`](https://swiftpackageindex.com/apple/swift-distributed-tracing/1.0.1/documentation/instrumentation/instrumentationsystem)
from `swift-distributed-tracing`.
This means that any of the libraries you use (that support *Swift Distributed Tracing*) will automatically create spans
transparently using ``OTelTracer``, no intermediary libraries needed.

> Tip: Prefer using the `Tracer` protocol in your application code instead of ``OTelTracer`` directly.
This makes it easier to switch to a different tracer if needed and makes your code more portable.

## Integrations

@Links(visualStyle: detailedGrid) {
    - <doc:log-correlation>
}

## Sample Code

A collection of Swift OTel examples that make use of Distributed Tracing.

@Links(visualStyle: detailedGrid) {
    - <doc:counter-sample>
}

## Topics

### Tracing

- ``OTelTracer``
- ``OTelSpan``

### Processing Spans

- ``OTelSpanProcessor``
- ``OTelBatchSpanProcessor``
- ``OTelBatchSpanProcessorConfiguration``
- ``OTelSimpleSpanProcessor``
- ``OTelMultiplexSpanProcessor``
- ``OTelNoOpSpanProcessor``
- ``OTelFinishedSpan``

### Exporting Spans

- ``OTelSpanExporter``
- ``OTelMultiplexSpanExporter``
- ``OTelNoOpSpanExporter``
- ``OTelSpanExporterAlreadyShutDownError``

### Sampling Spans

- ``OTelSampler``
- ``OTelSamplingResult``
- ``OTelParentBasedSampler``
- ``OTelConstantSampler``

### Generating IDs

- ``OTelIDGenerator``
- ``OTelRandomIDGenerator``

### Propagating Context

- ``OTelSpanContext``
- ``ServiceContextModule/ServiceContext``
- ``OTelPropagator``
- ``OTelW3CPropagator``
- ``OTelMultiplexPropagator``

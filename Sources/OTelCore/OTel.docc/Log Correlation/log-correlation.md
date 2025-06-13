# Log Correlation

Connect Distributed Tracing with Logging.

@Metadata {
    @Available("Swift OTel", introduced: "1.0")
    @PageImage(purpose: card, source: "log-correlation-card", alt: "An illustration of logs correlated with spans.")
}

## Overview

Log correlation connects [Distributed Tracing](<doc:tracing>) with Logging.
It enables you to take a trace/span ID from a log statement's metadata fields and inspect the corresponding trace in
your configured observability platform. Even better, when using the same platform for Distributed Tracing and Logging,
it will even display this connection directly, making it easy to go from log statement to trace and vice versa.

Swift OTel supports log correlation by implementing the
[`MetadataProvider`](https://swiftpackageindex.com/apple/swift-log/1.5.3/documentation/logging/logger/metadataprovider-swift.struct)
type from [`swift-log`](https://github.com/apple/swift-log), unlocking something **truly magical 🪄**

**All log statements** made within a traced context **automatically** get metadata values for the current **trace id,
span id, and trace flags**. This **includes all of your dependencies** that use `swift-log` for Logging.

@Image(source: "log-correlation-card", alt: "An illustration of logs correlated with spans.") {
    Log statements automatically linked to distributed tracing spans.
}

## Using the metadata provider

The metadata provider is straightforward to set up. Pass it along when bootstrapping your
[`LoggingSystem`](https://swiftpackageindex.com/apple/swift-log/1.5.3/documentation/logging/loggingsystem) like this:

```swift
LoggingSystem.bootstrap(StreamLogHandler.init, metadataProvider: .otel)
```

This makes use of the ``Logging/Logger/MetadataProvider/otel`` extension on `Logger.MetadataProvider`. You can also
use the ``Logging/Logger/MetadataProvider/otel(traceIDKey:spanIDKey:traceFlagsKey:parentSpanIDKey:)`` alternative if
you want to configure the metadata keys and optionally enable the inclusion of the parent span id:

```swift
let metadataProvider = Logger.MetadataProvider.otel(
    traceIDKey: "trace-id",
    spanIDKey: "span-id",
    traceFlagsKey: "trace-flags",
    parentSpanIDKey: "parent-span-id"
)

LoggingSystem.bootstrap(StreamLogHandler.init, metadataProvider: metadataProvider)
```

> Note: It doesn't really matter which log handler you're using as long as it supports metadata providers.

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2024 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIOConcurrencyHelpers
import ServiceLifecycle
import Tracing
import W3CTraceContext

/// An OpenTelemetry tracer implementing the Swift Distributed Tracing `Tracer` protocol.
///
/// The tracer has value semantics with respect to its ID generator: calling ``setIDGenerator(_:)`` only affects
/// the mutated copy, while all copies share the same sampler, processor, event stream, and recording spans.
///
/// [OpenTelemetry Specification: Tracer](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/trace/api.md#tracer)
struct OTelTracer<
    Propagator: OTelPropagator,
    Processor: OTelSpanProcessor,
    Clock: _Concurrency.Clock
>: Sendable where Clock.Duration == Duration {
    private let storage: Storage
    private var idGenerator: NIOLockedValueBox<any RandomNumberGenerator & Sendable>

    init(
        idGenerator: any RandomNumberGenerator & Sendable,
        sampler: WrappedSampler,
        propagator: Propagator,
        processor: Processor,
        resource: OTelResource,
        logger: Logger,
        clock: Clock
    ) {
        self.idGenerator = .init(idGenerator)
        self.storage = Storage(
            sampler: sampler,
            propagator: propagator,
            processor: processor,
            resource: resource,
            logger: logger.withMetadata(component: "OTelTracer")
        )
    }

    /// The state shared by all copies of a tracer.
    private final class Storage: Sendable {
        let sampler: WrappedSampler
        let propagator: Propagator
        let processor: Processor
        let resource: OTelResource
        let logger: Logger

        let eventStream: AsyncStream<Event>
        let eventStreamContinuation: AsyncStream<Event>.Continuation

        // TODO: this should likely be part of the value type? (look at activeSpan again)
        let recordingSpans = NIOLockedValueBox([OTelSpanContext: OTelSpan]())

        init(sampler: WrappedSampler, propagator: Propagator, processor: Processor, resource: OTelResource, logger: Logger) {
            self.sampler = sampler
            self.propagator = propagator
            self.processor = processor
            self.resource = resource
            self.logger = logger
            (eventStream, eventStreamContinuation) = AsyncStream.makeStream()
        }

        func process(_ span: OTelRecordingSpan, endedAt endTimeNanosecondsSinceEpoch: UInt64) {
            guard let spanContext = span.context.spanContext else { return }
            let finishedSpan = OTelFinishedSpan(
                spanContext: spanContext,
                operationName: span.operationName,
                kind: span.kind,
                status: span.status,
                startTimeNanosecondsSinceEpoch: span.startTimeNanosecondsSinceEpoch,
                endTimeNanosecondsSinceEpoch: endTimeNanosecondsSinceEpoch,
                attributes: span.attributes,
                resource: resource,
                events: span.events,
                links: span.links
            )
            eventStreamContinuation.yield(.spanEnded(finishedSpan))
        }
    }

    private enum Event {
        case spanStarted(_ span: OTelSpan, parentContext: ServiceContext)
        case spanEnded(_ span: OTelFinishedSpan)
        case forceFlushed
    }
}

extension OTelTracer where Clock == ContinuousClock {
    /// Create a new tracer.
    ///
    /// - Parameters:
    ///   - idGenerator: The generator used to create trace/span IDs.
    ///   - sampler: The sampler deciding whether to process/export spans.
    ///   - propagator: The propagator injecting/extracting span contexts.
    ///   - processor: The processor handling started/ended spans.
    ///   - environment: The environment variables.
    ///   - resource: Attributes about the resource being traced. Should be obtained using <doc:resource-detection>.
    init(
        idGenerator: any RandomNumberGenerator & Sendable,
        sampler: WrappedSampler,
        propagator: Propagator,
        processor: Processor,
        resource: OTelResource,
        logger: Logger
    ) {
        self.init(
            idGenerator: idGenerator,
            sampler: sampler,
            propagator: propagator,
            processor: processor,
            resource: resource,
            logger: logger,
            clock: .continuous
        )
    }
}

extension OTelTracer: Service {
    func run() async throws {
        let storage = storage
        storage.logger.debug("Starting.")
        await withGracefulShutdownHandler {
            for await event in storage.eventStream {
                // We don't want to propagate the current span's service context into
                // processing or exporting since it's not part of the span's scope.
                await ServiceContext.$current.withValue(nil) {
                    switch event {
                    case .spanStarted(let span, let parentContext):
                        storage.processor.onStart(span, parentContext: parentContext)
                    case .spanEnded(let span):
                        storage.processor.onEnd(span)
                    case .forceFlushed:
                        try? await storage.processor.forceFlush()
                    }
                }
            }
        } onGracefulShutdown: {
            storage.logger.debug("Shutting down.")
            storage.eventStreamContinuation.finish()
        }
        storage.logger.debug("Shut down.")
    }
}

private let noOpSpan = OTelSpan.noOp(NoOpTracer.NoOpSpan(context: .topLevel))

extension OTelTracer: Tracer {
    func startSpan(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> some TracerInstant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> OTelSpan {
        // Fast-path for constant sampler.
        // This breaks the OTel spec, which says a dropped span should still get a fresh, propagatable
        // context, but we value the performance of this common always-off case more.
        // — source: https://opentelemetry.io/docs/specs/otel/trace/sdk/#sdk-span-creation
        if case .constant(let sampler) = storage.sampler, sampler.decision == .drop { return noOpSpan }

        let parentContext = context()

        let traceID: TraceID
        let traceState: TraceState
        if let parentSpanContext = parentContext.spanContext {
            traceID = parentSpanContext.traceID
            traceState = parentSpanContext.traceState
        } else {
            traceID = idGenerator.withLockedValue { .random(using: &$0) }
            traceState = TraceState()
        }

        let samplingResult = storage.sampler.samplingResult(
            operationName: operationName,
            kind: kind,
            traceID: traceID,
            attributes: [:],
            links: [],
            parentContext: parentContext
        )

        let spanID: SpanID = idGenerator.withLockedValue { .random(using: &$0) }
        var childContext = parentContext

        let traceFlags: TraceFlags = samplingResult.decision == .recordAndSample ? .sampled : []
        let spanContext = OTelSpanContext.local(
            traceID: traceID,
            spanID: spanID,
            parentSpanID: parentContext.spanContext?.spanID,
            traceFlags: traceFlags,
            traceState: traceState
        )
        childContext.spanContext = spanContext

        switch samplingResult.decision {
        case .drop:
            return OTelSpan.noOp(NoOpTracer.NoOpSpan(context: childContext))

        case .record, .recordAndSample:
            let recordingSpan = OTelSpan.recording(
                operationName: operationName,
                kind: kind,
                context: childContext,
                spanContext: spanContext,
                attributes: samplingResult.attributes,
                startTimeNanosecondsSinceEpoch: instant().nanosecondsSinceEpoch,
                onEnd: { [weak storage] span, endTimeNanosecondsSinceEpoch in
                    storage?.process(span, endedAt: endTimeNanosecondsSinceEpoch)
                    storage?.recordingSpans.withLockedValue { $0[spanContext] = nil }
                }
            )
            storage.recordingSpans.withLockedValue { $0[spanContext] = recordingSpan }
            let span = recordingSpan
            storage.eventStreamContinuation.yield(.spanStarted(span, parentContext: parentContext))
            return span
        }
    }

    func forceFlush() {
        storage.eventStreamContinuation.yield(.forceFlushed)
    }

    func activeSpan(identifiedBy context: ServiceContext) -> OTelSpan? {
        guard let spanContext = context.spanContext else { return nil }
        guard let recordingSpan = storage.recordingSpans.withLockedValue({ $0[spanContext] }) else { return nil }
        return recordingSpan
    }

    mutating func setIDGenerator(_ generator: some RandomNumberGenerator & Sendable) {
        idGenerator = .init(generator)
    }
}

extension OTelTracer: Instrument {
    func inject<Carrier, Inject>(
        _ context: ServiceContext,
        into carrier: inout Carrier,
        using injector: Inject
    ) where Carrier == Inject.Carrier, Inject: Injector {
        guard let spanContext = context.spanContext else { return }
        storage.propagator.inject(spanContext, into: &carrier, using: injector)
    }

    func extract<Carrier, Extract>(
        _ carrier: Carrier,
        into context: inout ServiceContext,
        using extractor: Extract
    ) where Carrier == Extract.Carrier, Extract: Extractor {
        do {
            context.spanContext = try storage.propagator.extractSpanContext(from: carrier, using: extractor)
        } catch {
            storage.logger.warning("Failed to extract span context.", error: error, metadata: ["carrier": "\(carrier)"])
        }
    }
}

extension OTelTracer: CustomStringConvertible {
    var description: String { "OTelTracer" }
}

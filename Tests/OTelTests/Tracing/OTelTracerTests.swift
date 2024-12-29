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
@testable @_spi(Testing) import OTel
import OTelTesting
import ServiceContextModule
import ServiceLifecycle
import W3CTraceContext
import XCTest

final class OTelTracerTests: XCTestCase {
    override func setUp() async throws {
        LoggingSystem.bootstrapInternal(logLevel: .trace)
    }

    // MARK: - Tracer

    func test_startSpan_withoutParentSpanContext_generatesNewTraceID() throws {
        let idGenerator = OTelConstantIDGenerator(traceID: .oneToSixteen, spanID: .oneToEight)
        let sampler = OTelConstantSampler(isOn: true)
        let propagator = OTelW3CPropagator()
        let processor = OTelNoOpSpanProcessor()

        let tracer = OTelTracer(
            idGenerator: idGenerator,
            sampler: sampler,
            propagator: propagator,
            processor: processor,
            environment: [:],
            resource: OTelResource()
        )

        let span = tracer.startSpan("test")
        let spanContext = try XCTUnwrap(span.context.spanContext)
        XCTAssertEqual(
            spanContext,
            .local(
                traceID: .oneToSixteen,
                spanID: .oneToEight,
                parentSpanID: nil,
                traceFlags: .sampled,
                traceState: TraceState()
            )
        )
    }

    func test_startSpan_withParentSpanContext_reusesTraceID() throws {
        let idGenerator = OTelConstantIDGenerator(traceID: .oneToSixteen, spanID: .oneToEight)
        let randomIDGenerator = OTelRandomIDGenerator()
        let sampler = OTelConstantSampler(isOn: true)
        let propagator = OTelW3CPropagator()
        let processor = OTelNoOpSpanProcessor()

        let tracer = OTelTracer(
            idGenerator: idGenerator,
            sampler: sampler,
            propagator: propagator,
            processor: processor,
            environment: [:],
            resource: OTelResource()
        )

        let traceID = randomIDGenerator.nextTraceID()
        let parentSpanID = randomIDGenerator.nextSpanID()
        let traceState = TraceState([(.simple("foo"), "bar")])

        var parentContext = ServiceContext.topLevel
        let parentSpanContext = OTelSpanContext.remoteStub(
            traceID: traceID,
            spanID: parentSpanID,
            traceFlags: .sampled,
            traceState: traceState
        )
        parentContext.spanContext = parentSpanContext

        let span = tracer.startSpan("test", context: parentContext)
        let spanContext = try XCTUnwrap(span.context.spanContext)
        XCTAssertEqual(
            spanContext,
            .local(
                traceID: traceID,
                spanID: .oneToEight,
                parentSpanID: parentSpanID,
                traceFlags: .sampled,
                traceState: traceState
            )
        )
    }

    func test_startSpan_whenSamplerDrops_doesNotSetSampledFlag() throws {
        let idGenerator = OTelConstantIDGenerator(traceID: .oneToSixteen, spanID: .oneToEight)
        let sampler = OTelConstantSampler(decision: .drop)
        let propagator = OTelW3CPropagator()
        let processor = OTelNoOpSpanProcessor()

        let tracer = OTelTracer(
            idGenerator: idGenerator,
            sampler: sampler,
            propagator: propagator,
            processor: processor,
            environment: [:],
            resource: OTelResource()
        )

        let span = tracer.startSpan("test")
        let spanContext = try XCTUnwrap(span.context.spanContext)
        XCTAssertEqual(
            spanContext,
            .local(
                traceID: .oneToSixteen,
                spanID: .oneToEight,
                parentSpanID: nil,
                traceFlags: [],
                traceState: TraceState()
            )
        )
    }

    func test_startSpan_whenSamplerRecordsWithoutSampling_doesNotSetSampledFlag() throws {
        let idGenerator = OTelConstantIDGenerator(traceID: .oneToSixteen, spanID: .oneToEight)
        let sampler = OTelConstantSampler(decision: .record)
        let propagator = OTelW3CPropagator()
        let processor = OTelNoOpSpanProcessor()

        let tracer = OTelTracer(
            idGenerator: idGenerator,
            sampler: sampler,
            propagator: propagator,
            processor: processor,
            environment: [:],
            resource: OTelResource()
        )

        let span = tracer.startSpan("test")
        let spanContext = try XCTUnwrap(span.context.spanContext)
        XCTAssertEqual(
            spanContext,
            .local(
                traceID: .oneToSixteen,
                spanID: .oneToEight,
                parentSpanID: nil,
                traceFlags: [],
                traceState: TraceState()
            )
        )
    }

    func test_startSpan_whenSamplerDrops_usesNoOpSpan() throws {
        let idGenerator = OTelConstantIDGenerator(traceID: .oneToSixteen, spanID: .oneToEight)
        let sampler = OTelConstantSampler(decision: .drop)
        let propagator = OTelW3CPropagator()
        let processor = OTelNoOpSpanProcessor()

        let tracer = OTelTracer(
            idGenerator: idGenerator,
            sampler: sampler,
            propagator: propagator,
            processor: processor,
            environment: [:],
            resource: OTelResource()
        )

        let span = tracer.startSpan("test")
        XCTAssertFalse(span.isRecording)
        XCTAssertEqual(span.operationName, "noop")
    }

    func test_startSpan_onSpanEnd_whenSpanIsSampled_forwardsSpanToProcessor() async throws {
        let idGenerator = OTelRandomIDGenerator()
        let sampler = OTelConstantSampler(isOn: true)
        let propagator = OTelW3CPropagator()
        let exporter = OTelStreamingSpanExporter()
        var batches = await exporter.batches.makeAsyncIterator()
        let processor = OTelSimpleSpanProcessor(exporter: exporter)

        let tracer = OTelTracer(
            idGenerator: idGenerator,
            sampler: sampler,
            propagator: propagator,
            processor: processor,
            environment: [:],
            resource: OTelResource(attributes: ["service.name": "test"])
        )

        let logger = Logger(label: #function)
        let serviceGroup = ServiceGroup(services: [tracer], logger: logger)

        Task {
            try await serviceGroup.run()
        }

        let span = tracer.startSpan("1")
        span.end()

        let batch1 = await batches.next()
        let finishedSpan = try XCTUnwrap(batch1?.first)
        XCTAssertEqual(finishedSpan.operationName, "1")
        XCTAssertEqual(finishedSpan.resource.attributes["service.name"]?.toSpanAttribute(), "test")

        await serviceGroup.triggerGracefulShutdown()
    }

    func test_startSpan_onSpanEnd_whenSpanWasDropped_doesNotForwardSpanToProcessor() async throws {
        let idGenerator = OTelRandomIDGenerator()
        let sampler = OTelInlineSampler { operationName, _, _, _, _, _ in
            operationName == "1" ? .init(decision: .drop) : .init(decision: .recordAndSample)
        }
        let propagator = OTelW3CPropagator()
        let exporter = OTelStreamingSpanExporter()
        var batches = await exporter.batches.makeAsyncIterator()
        let processor = OTelSimpleSpanProcessor(exporter: exporter)

        let tracer = OTelTracer(
            idGenerator: idGenerator,
            sampler: sampler,
            propagator: propagator,
            processor: processor,
            environment: [:],
            resource: OTelResource()
        )

        let logger = Logger(label: #function)
        let serviceGroup = ServiceGroup(services: [tracer], logger: logger)

        Task {
            try await serviceGroup.run()
        }

        let span1 = tracer.startSpan("1")
        span1.end()

        let span2 = tracer.startSpan("2")
        span2.end()

        let batch1 = await batches.next()
        XCTAssertEqual(try XCTUnwrap(batch1).map(\.operationName), ["2"])

        await serviceGroup.triggerGracefulShutdown()
    }

    func test_forceFlush_forceFlushesProcessor() async throws {
        let idGenerator = OTelRandomIDGenerator()
        let sampler = OTelConstantSampler(isOn: true)
        let propagator = OTelW3CPropagator()
        let exporter = OTelStreamingSpanExporter()
        let clock = TestClock()
        let processor = OTelBatchSpanProcessor(exporter: exporter, configuration: .init(environment: [:]), clock: clock)

        let tracer = OTelTracer(
            idGenerator: idGenerator,
            sampler: sampler,
            propagator: propagator,
            processor: processor,
            environment: [:],
            resource: OTelResource()
        )

        let logger = Logger(label: #function)
        let serviceGroup = ServiceGroup(services: [tracer], logger: logger)

        Task {
            try await serviceGroup.run()
        }

        // We use the processor's first sleep as an indicator for when the tracer started running.
        var sleeps = clock.sleepCalls.makeAsyncIterator()
        await sleeps.next()

        let span = tracer.startSpan("test")
        span.end()

        tracer.forceFlush()

        var batches = await exporter.batches.makeAsyncIterator()
        let batch = await batches.next()

        XCTAssertEqual(try XCTUnwrap(batch).map(\.operationName), ["test"])
    }

    func test_spanIdentifiedByServiceContext_withoutSpanContext_returnsSpan() {
        let tracer = OTelTracer(
            idGenerator: OTelRandomIDGenerator(),
            sampler: OTelConstantSampler(isOn: true),
            propagator: OTelW3CPropagator(),
            processor: OTelNoOpSpanProcessor(),
            environment: [:],
            resource: OTelResource()
        )

        XCTAssertNil(tracer.recordingSpan(identifiedBy: .topLevel))
    }

    func test_spanIdentifiedByServiceContext_withSpanContext_identifyingRecordingSpan_returnsSpan() async {
        let tracer = OTelTracer(
            idGenerator: OTelRandomIDGenerator(),
            sampler: OTelConstantSampler(isOn: true),
            propagator: OTelW3CPropagator(),
            processor: OTelNoOpSpanProcessor(),
            environment: [:],
            resource: OTelResource()
        )

        let span = tracer.startSpan("test")
        XCTAssertIdentical(span, tracer.recordingSpan(identifiedBy: span.context))
    }

    func test_spanIdentifiedByServiceContext_withSpanContext_identifyingEndedSpan_returnsNil() async {
        let tracer = OTelTracer(
            idGenerator: OTelRandomIDGenerator(),
            sampler: OTelConstantSampler(isOn: true),
            propagator: OTelW3CPropagator(),
            processor: OTelNoOpSpanProcessor(),
            environment: [:],
            resource: OTelResource()
        )

        let span = tracer.startSpan("test")
        span.end()

        XCTAssertNil(tracer.recordingSpan(identifiedBy: span.context))
    }

    // MARK: - Instrument

    func test_inject_withSpanContext_callsPropagator() {
        let idGenerator = OTelRandomIDGenerator()
        let propagator = OTelInMemoryPropagator()
        let tracer = OTelTracer(
            idGenerator: idGenerator,
            sampler: OTelConstantSampler(isOn: true),
            propagator: propagator,
            processor: OTelNoOpSpanProcessor(),
            environment: [:],
            resource: OTelResource()
        )

        var context = ServiceContext.topLevel
        let spanContext = OTelSpanContext.local(
            traceID: idGenerator.nextTraceID(),
            spanID: idGenerator.nextSpanID(),
            parentSpanID: idGenerator.nextSpanID(),
            traceFlags: .sampled,
            traceState: TraceState()
        )
        context.spanContext = spanContext

        var dictionary = [String: String]()
        tracer.inject(context, into: &dictionary, using: DictionaryInjector())
        XCTAssertEqual(propagator.injectedSpanContexts, [spanContext])
    }

    func test_inject_withoutSpanContext_doesNotCallPropagator() {
        let propagator = OTelInMemoryPropagator()
        let tracer = OTelTracer(
            idGenerator: OTelRandomIDGenerator(),
            sampler: OTelConstantSampler(isOn: true),
            propagator: propagator,
            processor: OTelNoOpSpanProcessor(),
            environment: [:],
            resource: OTelResource()
        )

        var dictionary = [String: String]()
        tracer.inject(.topLevel, into: &dictionary, using: DictionaryInjector())
        XCTAssertTrue(propagator.injectedSpanContexts.isEmpty)
    }

    func test_extract_callsPropagator() throws {
        let idGenerator = OTelRandomIDGenerator()
        let spanContext = OTelSpanContext.local(
            traceID: idGenerator.nextTraceID(),
            spanID: idGenerator.nextSpanID(),
            parentSpanID: idGenerator.nextSpanID(),
            traceFlags: .sampled,
            traceState: TraceState()
        )
        let propagator = OTelInMemoryPropagator(extractionResult: .success(spanContext))
        let tracer = OTelTracer(
            idGenerator: idGenerator,
            sampler: OTelConstantSampler(isOn: true),
            propagator: propagator,
            processor: OTelNoOpSpanProcessor(),
            environment: [:],
            resource: OTelResource()
        )

        var context = ServiceContext.topLevel
        let dictionary = ["foo": "bar"]

        tracer.extract(dictionary, into: &context, using: DictionaryExtractor())

        XCTAssertEqual(context.spanContext, spanContext)
        XCTAssertEqual(try XCTUnwrap(propagator.extractedCarriers as? [[String: String]]), [dictionary])
    }

    func test_extract_whenPropagatorFails_keepsRunning() async throws {
        struct TestError: Error {}
        let idGenerator = OTelRandomIDGenerator()
        let exporter = OTelStreamingSpanExporter()
        let clock = TestClock()
        let processor = OTelBatchSpanProcessor(exporter: exporter, configuration: .init(environment: [:]), clock: clock)
        let propagator = OTelInMemoryPropagator(extractionResult: .failure(TestError()))
        let tracer = OTelTracer(
            idGenerator: idGenerator,
            sampler: OTelConstantSampler(isOn: true),
            propagator: propagator,
            processor: processor,
            environment: [:],
            resource: OTelResource()
        )

        let logger = Logger(label: #function)
        let serviceGroup = ServiceGroup(services: [tracer], logger: logger)
        Task {
            try await serviceGroup.run()
        }

        var context = ServiceContext.topLevel
        tracer.extract([:], into: &context, using: DictionaryExtractor())

        let span = tracer.startSpan("test")
        span.end()

        // We use the processor's first sleep as an indicator for when the tracer started running.
        var sleeps = clock.sleepCalls.makeAsyncIterator()
        await sleeps.next()

        await serviceGroup.triggerGracefulShutdown()

        var batches = await exporter.batches.makeAsyncIterator()
        let batch = await batches.next()
        XCTAssertEqual(try XCTUnwrap(batch).map(\.operationName), ["test"])
    }
}

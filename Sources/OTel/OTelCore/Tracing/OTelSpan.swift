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

import NIOConcurrencyHelpers
import Tracing

/// A distributed tracing span, conforming to the [OpenTelemetry specification](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/trace/api.md#span).
final class OTelSpan: Span {
    private let underlying: Underlying

    var context: ServiceContext {
        switch underlying {
        case .noOp(let span):
            return span.context
        case .recording(let span, _):
            return span.context
        }
    }

    var isRecording: Bool {
        switch underlying {
        case .noOp:
            return false
        case .recording(let span, _):
            return span.isRecording
        }
    }

    var operationName: String {
        get {
            switch underlying {
            case .noOp(let span):
                return span.operationName
            case .recording(let span, _):
                return span.operationName
            }
        }
        set {
            switch underlying {
            case .noOp:
                break
            case .recording(let span, _):
                guard span.isRecording else { return }
                span.operationName = newValue
            }
        }
    }

    var attributes: SpanAttributes {
        get {
            switch underlying {
            case .noOp:
                return [:]
            case .recording(let span, _):
                return span.attributes
            }
        }
        set {
            switch underlying {
            case .noOp:
                break
            case .recording(let span, _):
                guard span.isRecording else { return }
                span.attributes = newValue
            }
        }
    }

    var events: [SpanEvent] {
        switch underlying {
        case .noOp:
            return []
        case .recording(let span, _):
            return span.events
        }
    }

    var links: [SpanLink] {
        switch underlying {
        case .noOp:
            return []
        case .recording(let span, _):
            return span.links
        }
    }

    var status: SpanStatus? {
        switch underlying {
        case .noOp:
            return nil
        case .recording(let span, _):
            return span.status
        }
    }

    var endTimeNanosecondsSinceEpoch: UInt64? {
        switch underlying {
        case .noOp:
            return nil
        case .recording(let span, _):
            return span.endTimeNanosecondsSinceEpoch
        }
    }

    func setStatus(_ status: SpanStatus) {
        switch underlying {
        case .noOp:
            break
        case .recording(let span, _):
            guard span.isRecording else { return }
            span.setStatus(status)
        }
    }

    func addEvent(_ event: Tracing.SpanEvent) {
        switch underlying {
        case .noOp:
            break
        case .recording(let span, _):
            guard span.isRecording else { return }
            span.addEvent(event)
        }
    }

    func recordError(
        _ error: Error,
        attributes: SpanAttributes,
        at instant: @autoclosure () -> some TracerInstant
    ) {
        switch underlying {
        case .noOp:
            break
        case .recording(let span, _):
            guard span.isRecording else { return }
            span.recordError(error, attributes: attributes, at: instant())
        }
    }

    func addLink(_ link: SpanLink) {
        switch underlying {
        case .noOp:
            break
        case .recording(let span, _):
            guard span.isRecording else { return }
            span.addLink(link)
        }
    }

    func end(at instant: @autoclosure () -> some TracerInstant) {
        switch underlying {
        case .noOp:
            break
        case .recording(let span, _):
            guard span.isRecording else { return }
            span.end(at: instant())
        }
    }

    private init(underlying: Underlying) {
        self.underlying = underlying
    }

    static func noOp(_ span: NoOpTracer.NoOpSpan) -> OTelSpan {
        OTelSpan(underlying: .noOp(span))
    }

    static func recording(
        operationName: String,
        kind: SpanKind,
        context: ServiceContext,
        spanContext: OTelSpanContext,
        attributes: SpanAttributes,
        startTimeNanosecondsSinceEpoch: UInt64,
        onEnd: @escaping @Sendable (OTelRecordingSpan, _ endTimeNanosecondsSinceEpoch: UInt64) -> Void
    ) -> OTelSpan {
        OTelSpan(
            underlying: .recording(
                OTelRecordingSpan(
                    operationName: operationName,
                    kind: kind,
                    context: context,
                    attributes: attributes,
                    startTimeNanosecondsSinceEpoch: startTimeNanosecondsSinceEpoch,
                    onEnd: onEnd
                ),
                kind: kind
            )
        )
    }

    private enum Underlying {
        case noOp(NoOpTracer.NoOpSpan)
        case recording(OTelRecordingSpan, kind: SpanKind)
    }
}

final class OTelRecordingSpan: Span, Sendable {
    let kind: SpanKind
    let context: ServiceContext

    private struct State {
        var operationName: String
        var attributes: SpanAttributes
        var status: SpanStatus?
        var events: [SpanEvent]
        var links: [SpanLink]
        var endTimeNanosecondsSinceEpoch: UInt64?
    }

    private let _state: NIOLockedValueBox<State>

    var operationName: String {
        get { _state.withLockedValue { $0.operationName } }
        set { _state.withLockedValue { $0.operationName = newValue } }
    }

    var attributes: SpanAttributes {
        get { _state.withLockedValue { $0.attributes } }
        set { _state.withLockedValue { $0.attributes = newValue } }
    }

    var status: SpanStatus? { _state.withLockedValue { $0.status } }

    var events: [SpanEvent] { _state.withLockedValue { $0.events } }

    var links: [SpanLink] { _state.withLockedValue { $0.links } }

    let startTimeNanosecondsSinceEpoch: UInt64

    var endTimeNanosecondsSinceEpoch: UInt64? { _state.withLockedValue { $0.endTimeNanosecondsSinceEpoch } }

    private let onEnd: @Sendable (OTelRecordingSpan, _ endTimeNanosecondsSinceEpoch: UInt64) -> Void

    var isRecording: Bool { endTimeNanosecondsSinceEpoch == nil }

    init(
        operationName: String,
        kind: SpanKind,
        context: ServiceContext,
        attributes: SpanAttributes,
        startTimeNanosecondsSinceEpoch: UInt64,
        onEnd: @escaping @Sendable (OTelRecordingSpan, _ endTimeNanosecondsSinceEpoch: UInt64) -> Void
    ) {
        self.kind = kind
        self.context = context
        self.startTimeNanosecondsSinceEpoch = startTimeNanosecondsSinceEpoch
        self.onEnd = onEnd
        _state = NIOLockedValueBox(
            State(
                operationName: operationName,
                attributes: attributes,
                events: [],
                links: []
            )
        )
    }

    func setStatus(_ status: SpanStatus) {
        // When span status is set to Ok it SHOULD be considered final
        // and any further attempts to change it SHOULD be ignored.
        // https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/trace/api.md#set-status
        guard self.status?.code != .ok else { return }

        let status: SpanStatus = {
            switch status.code {
            case .ok:
                // Description MUST be IGNORED for StatusCode Ok & Unset values.
                // https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/trace/api.md#set-status
                return SpanStatus(code: .ok, message: nil)
            case .error:
                return status
            }
        }()

        _state.withLockedValue { $0.status = status }
    }

    func addEvent(_ event: SpanEvent) {
        _state.withLockedValue { $0.events.append(event) }
    }

    func recordError(
        _ error: Error,
        attributes: SpanAttributes,
        at instant: @autoclosure () -> some TracerInstant
    ) {
        var eventAttributes: SpanAttributes = [
            "exception.type": .string(String(describing: type(of: error))),
            "exception.message": .string(String(describing: error)),
        ]
        eventAttributes.merge(attributes)

        let event = SpanEvent(
            name: "exception",
            at: instant(),
            attributes: eventAttributes
        )
        addEvent(event)
    }

    func addLink(_ link: SpanLink) {
        _state.withLockedValue { $0.links.append(link) }
    }

    func end(at instant: @autoclosure () -> some TracerInstant) {
        let endTimeNanosecondsSinceEpoch = instant().nanosecondsSinceEpoch
        _state.withLockedValue { $0.endTimeNanosecondsSinceEpoch = endTimeNanosecondsSinceEpoch }
        onEnd(self, endTimeNanosecondsSinceEpoch)
    }
}

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
public final class OTelSpan: Span {
    private let underlying: Underlying

    public var context: ServiceContext {
        switch underlying {
        case .noOp(let span):
            return span.context
        case .recording(let span, _):
            return span.context
        }
    }

    public var isRecording: Bool {
        switch underlying {
        case .noOp:
            return false
        case .recording(let span, _):
            return span.isRecording
        }
    }

    public var operationName: String {
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

    public var attributes: SpanAttributes {
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

    public var events: [SpanEvent] {
        switch underlying {
        case .noOp:
            return []
        case .recording(let span, _):
            return span.events
        }
    }

    public var links: [SpanLink] {
        switch underlying {
        case .noOp:
            return []
        case .recording(let span, _):
            return span.links
        }
    }

    public var status: SpanStatus? {
        switch underlying {
        case .noOp:
            return nil
        case .recording(let span, _):
            return span.status
        }
    }

    public var endTimeNanosecondsSinceEpoch: UInt64? {
        switch underlying {
        case .noOp:
            return nil
        case .recording(let span, _):
            return span.endTimeNanosecondsSinceEpoch
        }
    }

    public func setStatus(_ status: SpanStatus) {
        switch underlying {
        case .noOp:
            break
        case .recording(let span, _):
            guard span.isRecording else { return }
            span.setStatus(status)
        }
    }

    public func addEvent(_ event: Tracing.SpanEvent) {
        switch underlying {
        case .noOp:
            break
        case .recording(let span, _):
            guard span.isRecording else { return }
            span.addEvent(event)
        }
    }

    public func recordError(
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

    public func addLink(_ link: SpanLink) {
        switch underlying {
        case .noOp:
            break
        case .recording(let span, _):
            guard span.isRecording else { return }
            span.addLink(link)
        }
    }

    public func end(at instant: @autoclosure () -> some TracerInstant) {
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
        OTelSpan(underlying: .recording(
            OTelRecordingSpan(
                operationName: operationName,
                kind: kind,
                context: context,
                attributes: attributes,
                startTimeNanosecondsSinceEpoch: startTimeNanosecondsSinceEpoch,
                onEnd: onEnd
            ),
            kind: kind
        ))
    }

    private enum Underlying {
        case noOp(NoOpTracer.NoOpSpan)
        case recording(OTelRecordingSpan, kind: SpanKind)
    }
}

final class OTelRecordingSpan: Span, Sendable {
    let kind: SpanKind
    let context: ServiceContext

    var operationName: String {
        get {
            _operationName.withLockedValue { $0 }
        }
        set {
            _operationName.withLockedValue { $0 = newValue }
        }
    }

    private let _operationName: NIOLockedValueBox<String>

    var attributes: SpanAttributes {
        get {
            _attributes.withLockedValue { $0 }
        }
        set {
            _attributes.withLockedValue { $0 = newValue }
        }
    }

    private let _attributes: NIOLockedValueBox<SpanAttributes>

    var status: SpanStatus? { _status.withLockedValue { $0 } }
    private let _status = NIOLockedValueBox<SpanStatus?>(nil)

    var events: [SpanEvent] { _events.withLockedValue { $0 } }
    private let _events = NIOLockedValueBox([SpanEvent]())

    var links: [SpanLink] { _links.withLockedValue { $0 } }
    private let _links = NIOLockedValueBox([SpanLink]())

    let startTimeNanosecondsSinceEpoch: UInt64

    var endTimeNanosecondsSinceEpoch: UInt64? { _endTimeNanosecondsSinceEpoch.withLockedValue { $0 } }
    private let _endTimeNanosecondsSinceEpoch = NIOLockedValueBox<UInt64?>(nil)

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
        _operationName = NIOLockedValueBox(operationName)
        self.kind = kind
        self.context = context
        _attributes = NIOLockedValueBox(attributes)
        self.startTimeNanosecondsSinceEpoch = startTimeNanosecondsSinceEpoch
        self.onEnd = onEnd
    }

    func setStatus(_ status: SpanStatus) {
        /*
         When span status is set to Ok it SHOULD be considered final
         and any further attempts to change it SHOULD be ignored.

         https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/trace/api.md#set-status
         */
        guard self.status?.code != .ok else { return }

        let status: SpanStatus = {
            switch status.code {
            case .ok:
                /*
                 Description MUST be IGNORED for StatusCode Ok & Unset values.

                 https://github.com/open-telemetry/opentelemetry-specification/blob/v1.20.0/specification/trace/api.md#set-status
                 */
                return SpanStatus(code: .ok, message: nil)
            case .error:
                return status
            }
        }()

        _status.withLockedValue { $0 = status }
    }

    func addEvent(_ event: SpanEvent) {
        _events.withLockedValue { $0.append(event) }
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
        _links.withLockedValue { $0.append(link) }
    }

    func end(at instant: @autoclosure () -> some TracerInstant) {
        let endTimeNanosecondsSinceEpoch = instant().nanosecondsSinceEpoch
        _endTimeNanosecondsSinceEpoch.withLockedValue { $0 = endTimeNanosecondsSinceEpoch }
        onEnd(self, endTimeNanosecondsSinceEpoch)
    }
}

#if !(OTLPHTTP || OTLPGRPC)
// Empty when above trait(s) are disabled.
#else
// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: opentelemetry/proto/logs/v1/logs.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package import Foundation
package import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

/// Possible values for LogRecord.SeverityNumber.
package enum Opentelemetry_Proto_Logs_V1_SeverityNumber: SwiftProtobuf.Enum, Swift.CaseIterable {
  package typealias RawValue = Int

  /// UNSPECIFIED is the default SeverityNumber, it MUST NOT be used.
  case unspecified // = 0
  case trace // = 1
  case trace2 // = 2
  case trace3 // = 3
  case trace4 // = 4
  case debug // = 5
  case debug2 // = 6
  case debug3 // = 7
  case debug4 // = 8
  case info // = 9
  case info2 // = 10
  case info3 // = 11
  case info4 // = 12
  case warn // = 13
  case warn2 // = 14
  case warn3 // = 15
  case warn4 // = 16
  case error // = 17
  case error2 // = 18
  case error3 // = 19
  case error4 // = 20
  case fatal // = 21
  case fatal2 // = 22
  case fatal3 // = 23
  case fatal4 // = 24
  case UNRECOGNIZED(Int)

  package init() {
    self = .unspecified
  }

  package init?(rawValue: Int) {
    switch rawValue {
    case 0: self = .unspecified
    case 1: self = .trace
    case 2: self = .trace2
    case 3: self = .trace3
    case 4: self = .trace4
    case 5: self = .debug
    case 6: self = .debug2
    case 7: self = .debug3
    case 8: self = .debug4
    case 9: self = .info
    case 10: self = .info2
    case 11: self = .info3
    case 12: self = .info4
    case 13: self = .warn
    case 14: self = .warn2
    case 15: self = .warn3
    case 16: self = .warn4
    case 17: self = .error
    case 18: self = .error2
    case 19: self = .error3
    case 20: self = .error4
    case 21: self = .fatal
    case 22: self = .fatal2
    case 23: self = .fatal3
    case 24: self = .fatal4
    default: self = .UNRECOGNIZED(rawValue)
    }
  }

  package var rawValue: Int {
    switch self {
    case .unspecified: return 0
    case .trace: return 1
    case .trace2: return 2
    case .trace3: return 3
    case .trace4: return 4
    case .debug: return 5
    case .debug2: return 6
    case .debug3: return 7
    case .debug4: return 8
    case .info: return 9
    case .info2: return 10
    case .info3: return 11
    case .info4: return 12
    case .warn: return 13
    case .warn2: return 14
    case .warn3: return 15
    case .warn4: return 16
    case .error: return 17
    case .error2: return 18
    case .error3: return 19
    case .error4: return 20
    case .fatal: return 21
    case .fatal2: return 22
    case .fatal3: return 23
    case .fatal4: return 24
    case .UNRECOGNIZED(let i): return i
    }
  }

  // The compiler won't synthesize support with the UNRECOGNIZED case.
  package static let allCases: [Opentelemetry_Proto_Logs_V1_SeverityNumber] = [
    .unspecified,
    .trace,
    .trace2,
    .trace3,
    .trace4,
    .debug,
    .debug2,
    .debug3,
    .debug4,
    .info,
    .info2,
    .info3,
    .info4,
    .warn,
    .warn2,
    .warn3,
    .warn4,
    .error,
    .error2,
    .error3,
    .error4,
    .fatal,
    .fatal2,
    .fatal3,
    .fatal4,
  ]

}

/// LogRecordFlags is defined as a protobuf 'uint32' type and is to be used as
/// bit-fields. Each non-zero value defined in this enum is a bit-mask.
/// To extract the bit-field, for example, use an expression like:
///
///   (logRecord.flags & LOG_RECORD_FLAGS_TRACE_FLAGS_MASK)
package enum Opentelemetry_Proto_Logs_V1_LogRecordFlags: SwiftProtobuf.Enum, Swift.CaseIterable {
  package typealias RawValue = Int

  /// The zero value for the enum. Should not be used for comparisons.
  /// Instead use bitwise "and" with the appropriate mask as shown above.
  case doNotUse // = 0

  /// Bits 0-7 are used for trace flags.
  case traceFlagsMask // = 255
  case UNRECOGNIZED(Int)

  package init() {
    self = .doNotUse
  }

  package init?(rawValue: Int) {
    switch rawValue {
    case 0: self = .doNotUse
    case 255: self = .traceFlagsMask
    default: self = .UNRECOGNIZED(rawValue)
    }
  }

  package var rawValue: Int {
    switch self {
    case .doNotUse: return 0
    case .traceFlagsMask: return 255
    case .UNRECOGNIZED(let i): return i
    }
  }

  // The compiler won't synthesize support with the UNRECOGNIZED case.
  package static let allCases: [Opentelemetry_Proto_Logs_V1_LogRecordFlags] = [
    .doNotUse,
    .traceFlagsMask,
  ]

}

/// LogsData represents the logs data that can be stored in a persistent storage,
/// OR can be embedded by other protocols that transfer OTLP logs data but do not
/// implement the OTLP protocol.
///
/// The main difference between this message and collector protocol is that
/// in this message there will not be any "control" or "metadata" specific to
/// OTLP protocol.
///
/// When new fields are added into this message, the OTLP request MUST be updated
/// as well.
package struct Opentelemetry_Proto_Logs_V1_LogsData: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// An array of ResourceLogs.
  /// For data coming from a single resource this array will typically contain
  /// one element. Intermediary nodes that receive data from multiple origins
  /// typically batch the data before forwarding further and in that case this
  /// array will contain multiple elements.
  package var resourceLogs: [Opentelemetry_Proto_Logs_V1_ResourceLogs] = []

  package var unknownFields = SwiftProtobuf.UnknownStorage()

  package init() {}
}

/// A collection of ScopeLogs from a Resource.
package struct Opentelemetry_Proto_Logs_V1_ResourceLogs: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// The resource for the logs in this message.
  /// If this field is not set then resource info is unknown.
  package var resource: Opentelemetry_Proto_Resource_V1_Resource {
    get {return _resource ?? Opentelemetry_Proto_Resource_V1_Resource()}
    set {_resource = newValue}
  }
  /// Returns true if `resource` has been explicitly set.
  package var hasResource: Bool {return self._resource != nil}
  /// Clears the value of `resource`. Subsequent reads from it will return its default value.
  package mutating func clearResource() {self._resource = nil}

  /// A list of ScopeLogs that originate from a resource.
  package var scopeLogs: [Opentelemetry_Proto_Logs_V1_ScopeLogs] = []

  /// This schema_url applies to the data in the "resource" field. It does not apply
  /// to the data in the "scope_logs" field which have their own schema_url field.
  package var schemaURL: String = String()

  package var unknownFields = SwiftProtobuf.UnknownStorage()

  package init() {}

  fileprivate var _resource: Opentelemetry_Proto_Resource_V1_Resource? = nil
}

/// A collection of Logs produced by a Scope.
package struct Opentelemetry_Proto_Logs_V1_ScopeLogs: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// The instrumentation scope information for the logs in this message.
  /// Semantically when InstrumentationScope isn't set, it is equivalent with
  /// an empty instrumentation scope name (unknown).
  package var scope: Opentelemetry_Proto_Common_V1_InstrumentationScope {
    get {return _scope ?? Opentelemetry_Proto_Common_V1_InstrumentationScope()}
    set {_scope = newValue}
  }
  /// Returns true if `scope` has been explicitly set.
  package var hasScope: Bool {return self._scope != nil}
  /// Clears the value of `scope`. Subsequent reads from it will return its default value.
  package mutating func clearScope() {self._scope = nil}

  /// A list of log records.
  package var logRecords: [Opentelemetry_Proto_Logs_V1_LogRecord] = []

  /// This schema_url applies to all logs in the "logs" field.
  package var schemaURL: String = String()

  package var unknownFields = SwiftProtobuf.UnknownStorage()

  package init() {}

  fileprivate var _scope: Opentelemetry_Proto_Common_V1_InstrumentationScope? = nil
}

/// A log record according to OpenTelemetry Log Data Model:
/// https://github.com/open-telemetry/oteps/blob/main/text/logs/0097-log-data-model.md
package struct Opentelemetry_Proto_Logs_V1_LogRecord: @unchecked Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// time_unix_nano is the time when the event occurred.
  /// Value is UNIX Epoch time in nanoseconds since 00:00:00 UTC on 1 January 1970.
  /// Value of 0 indicates unknown or missing timestamp.
  package var timeUnixNano: UInt64 = 0

  /// Time when the event was observed by the collection system.
  /// For events that originate in OpenTelemetry (e.g. using OpenTelemetry Logging SDK)
  /// this timestamp is typically set at the generation time and is equal to Timestamp.
  /// For events originating externally and collected by OpenTelemetry (e.g. using
  /// Collector) this is the time when OpenTelemetry's code observed the event measured
  /// by the clock of the OpenTelemetry code. This field MUST be set once the event is
  /// observed by OpenTelemetry.
  ///
  /// For converting OpenTelemetry log data to formats that support only one timestamp or
  /// when receiving OpenTelemetry log data by recipients that support only one timestamp
  /// internally the following logic is recommended:
  ///   - Use time_unix_nano if it is present, otherwise use observed_time_unix_nano.
  ///
  /// Value is UNIX Epoch time in nanoseconds since 00:00:00 UTC on 1 January 1970.
  /// Value of 0 indicates unknown or missing timestamp.
  package var observedTimeUnixNano: UInt64 = 0

  /// Numerical value of the severity, normalized to values described in Log Data Model.
  /// [Optional].
  package var severityNumber: Opentelemetry_Proto_Logs_V1_SeverityNumber = .unspecified

  /// The severity text (also known as log level). The original string representation as
  /// it is known at the source. [Optional].
  package var severityText: String = String()

  /// A value containing the body of the log record. Can be for example a human-readable
  /// string message (including multi-line) describing the event in a free form or it can
  /// be a structured data composed of arrays and maps of other values. [Optional].
  package var body: Opentelemetry_Proto_Common_V1_AnyValue {
    get {return _body ?? Opentelemetry_Proto_Common_V1_AnyValue()}
    set {_body = newValue}
  }
  /// Returns true if `body` has been explicitly set.
  package var hasBody: Bool {return self._body != nil}
  /// Clears the value of `body`. Subsequent reads from it will return its default value.
  package mutating func clearBody() {self._body = nil}

  /// Additional attributes that describe the specific event occurrence. [Optional].
  /// Attribute keys MUST be unique (it is not allowed to have more than one
  /// attribute with the same key).
  package var attributes: [Opentelemetry_Proto_Common_V1_KeyValue] = []

  package var droppedAttributesCount: UInt32 = 0

  /// Flags, a bit field. 8 least significant bits are the trace flags as
  /// defined in W3C Trace Context specification. 24 most significant bits are reserved
  /// and must be set to 0. Readers must not assume that 24 most significant bits
  /// will be zero and must correctly mask the bits when reading 8-bit trace flag (use
  /// flags & LOG_RECORD_FLAGS_TRACE_FLAGS_MASK). [Optional].
  package var flags: UInt32 = 0

  /// A unique identifier for a trace. All logs from the same trace share
  /// the same `trace_id`. The ID is a 16-byte array. An ID with all zeroes OR
  /// of length other than 16 bytes is considered invalid (empty string in OTLP/JSON
  /// is zero-length and thus is also invalid).
  ///
  /// This field is optional.
  ///
  /// The receivers SHOULD assume that the log record is not associated with a
  /// trace if any of the following is true:
  ///   - the field is not present,
  ///   - the field contains an invalid value.
  package var traceID: Data = Data()

  /// A unique identifier for a span within a trace, assigned when the span
  /// is created. The ID is an 8-byte array. An ID with all zeroes OR of length
  /// other than 8 bytes is considered invalid (empty string in OTLP/JSON
  /// is zero-length and thus is also invalid).
  ///
  /// This field is optional. If the sender specifies a valid span_id then it SHOULD also
  /// specify a valid trace_id.
  ///
  /// The receivers SHOULD assume that the log record is not associated with a
  /// span if any of the following is true:
  ///   - the field is not present,
  ///   - the field contains an invalid value.
  package var spanID: Data = Data()

  package var unknownFields = SwiftProtobuf.UnknownStorage()

  package init() {}

  fileprivate var _body: Opentelemetry_Proto_Common_V1_AnyValue? = nil
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "opentelemetry.proto.logs.v1"

extension Opentelemetry_Proto_Logs_V1_SeverityNumber: SwiftProtobuf._ProtoNameProviding {
  package static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "SEVERITY_NUMBER_UNSPECIFIED"),
    1: .same(proto: "SEVERITY_NUMBER_TRACE"),
    2: .same(proto: "SEVERITY_NUMBER_TRACE2"),
    3: .same(proto: "SEVERITY_NUMBER_TRACE3"),
    4: .same(proto: "SEVERITY_NUMBER_TRACE4"),
    5: .same(proto: "SEVERITY_NUMBER_DEBUG"),
    6: .same(proto: "SEVERITY_NUMBER_DEBUG2"),
    7: .same(proto: "SEVERITY_NUMBER_DEBUG3"),
    8: .same(proto: "SEVERITY_NUMBER_DEBUG4"),
    9: .same(proto: "SEVERITY_NUMBER_INFO"),
    10: .same(proto: "SEVERITY_NUMBER_INFO2"),
    11: .same(proto: "SEVERITY_NUMBER_INFO3"),
    12: .same(proto: "SEVERITY_NUMBER_INFO4"),
    13: .same(proto: "SEVERITY_NUMBER_WARN"),
    14: .same(proto: "SEVERITY_NUMBER_WARN2"),
    15: .same(proto: "SEVERITY_NUMBER_WARN3"),
    16: .same(proto: "SEVERITY_NUMBER_WARN4"),
    17: .same(proto: "SEVERITY_NUMBER_ERROR"),
    18: .same(proto: "SEVERITY_NUMBER_ERROR2"),
    19: .same(proto: "SEVERITY_NUMBER_ERROR3"),
    20: .same(proto: "SEVERITY_NUMBER_ERROR4"),
    21: .same(proto: "SEVERITY_NUMBER_FATAL"),
    22: .same(proto: "SEVERITY_NUMBER_FATAL2"),
    23: .same(proto: "SEVERITY_NUMBER_FATAL3"),
    24: .same(proto: "SEVERITY_NUMBER_FATAL4"),
  ]
}

extension Opentelemetry_Proto_Logs_V1_LogRecordFlags: SwiftProtobuf._ProtoNameProviding {
  package static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "LOG_RECORD_FLAGS_DO_NOT_USE"),
    255: .same(proto: "LOG_RECORD_FLAGS_TRACE_FLAGS_MASK"),
  ]
}

extension Opentelemetry_Proto_Logs_V1_LogsData: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  package static let protoMessageName: String = _protobuf_package + ".LogsData"
  package static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .standard(proto: "resource_logs"),
  ]

  package mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeRepeatedMessageField(value: &self.resourceLogs) }()
      default: break
      }
    }
  }

  package func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.resourceLogs.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.resourceLogs, fieldNumber: 1)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  package static func ==(lhs: Opentelemetry_Proto_Logs_V1_LogsData, rhs: Opentelemetry_Proto_Logs_V1_LogsData) -> Bool {
    if lhs.resourceLogs != rhs.resourceLogs {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Opentelemetry_Proto_Logs_V1_ResourceLogs: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  package static let protoMessageName: String = _protobuf_package + ".ResourceLogs"
  package static let _protobuf_nameMap = SwiftProtobuf._NameMap(
      reservedNames: [],
      reservedRanges: [1000..<1001],
      numberNameMappings: [
        1: .same(proto: "resource"),
        2: .standard(proto: "scope_logs"),
        3: .standard(proto: "schema_url"),
  ])

  package mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._resource) }()
      case 2: try { try decoder.decodeRepeatedMessageField(value: &self.scopeLogs) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.schemaURL) }()
      default: break
      }
    }
  }

  package func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._resource {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    if !self.scopeLogs.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.scopeLogs, fieldNumber: 2)
    }
    if !self.schemaURL.isEmpty {
      try visitor.visitSingularStringField(value: self.schemaURL, fieldNumber: 3)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  package static func ==(lhs: Opentelemetry_Proto_Logs_V1_ResourceLogs, rhs: Opentelemetry_Proto_Logs_V1_ResourceLogs) -> Bool {
    if lhs._resource != rhs._resource {return false}
    if lhs.scopeLogs != rhs.scopeLogs {return false}
    if lhs.schemaURL != rhs.schemaURL {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Opentelemetry_Proto_Logs_V1_ScopeLogs: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  package static let protoMessageName: String = _protobuf_package + ".ScopeLogs"
  package static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "scope"),
    2: .standard(proto: "log_records"),
    3: .standard(proto: "schema_url"),
  ]

  package mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._scope) }()
      case 2: try { try decoder.decodeRepeatedMessageField(value: &self.logRecords) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.schemaURL) }()
      default: break
      }
    }
  }

  package func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._scope {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    if !self.logRecords.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.logRecords, fieldNumber: 2)
    }
    if !self.schemaURL.isEmpty {
      try visitor.visitSingularStringField(value: self.schemaURL, fieldNumber: 3)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  package static func ==(lhs: Opentelemetry_Proto_Logs_V1_ScopeLogs, rhs: Opentelemetry_Proto_Logs_V1_ScopeLogs) -> Bool {
    if lhs._scope != rhs._scope {return false}
    if lhs.logRecords != rhs.logRecords {return false}
    if lhs.schemaURL != rhs.schemaURL {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Opentelemetry_Proto_Logs_V1_LogRecord: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  package static let protoMessageName: String = _protobuf_package + ".LogRecord"
  package static let _protobuf_nameMap = SwiftProtobuf._NameMap(
      reservedNames: [],
      reservedRanges: [4..<5],
      numberNameMappings: [
        1: .standard(proto: "time_unix_nano"),
        11: .standard(proto: "observed_time_unix_nano"),
        2: .standard(proto: "severity_number"),
        3: .standard(proto: "severity_text"),
        5: .same(proto: "body"),
        6: .same(proto: "attributes"),
        7: .standard(proto: "dropped_attributes_count"),
        8: .same(proto: "flags"),
        9: .standard(proto: "trace_id"),
        10: .standard(proto: "span_id"),
  ])

  package mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularFixed64Field(value: &self.timeUnixNano) }()
      case 2: try { try decoder.decodeSingularEnumField(value: &self.severityNumber) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.severityText) }()
      case 5: try { try decoder.decodeSingularMessageField(value: &self._body) }()
      case 6: try { try decoder.decodeRepeatedMessageField(value: &self.attributes) }()
      case 7: try { try decoder.decodeSingularUInt32Field(value: &self.droppedAttributesCount) }()
      case 8: try { try decoder.decodeSingularFixed32Field(value: &self.flags) }()
      case 9: try { try decoder.decodeSingularBytesField(value: &self.traceID) }()
      case 10: try { try decoder.decodeSingularBytesField(value: &self.spanID) }()
      case 11: try { try decoder.decodeSingularFixed64Field(value: &self.observedTimeUnixNano) }()
      default: break
      }
    }
  }

  package func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    if self.timeUnixNano != 0 {
      try visitor.visitSingularFixed64Field(value: self.timeUnixNano, fieldNumber: 1)
    }
    if self.severityNumber != .unspecified {
      try visitor.visitSingularEnumField(value: self.severityNumber, fieldNumber: 2)
    }
    if !self.severityText.isEmpty {
      try visitor.visitSingularStringField(value: self.severityText, fieldNumber: 3)
    }
    try { if let v = self._body {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 5)
    } }()
    if !self.attributes.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.attributes, fieldNumber: 6)
    }
    if self.droppedAttributesCount != 0 {
      try visitor.visitSingularUInt32Field(value: self.droppedAttributesCount, fieldNumber: 7)
    }
    if self.flags != 0 {
      try visitor.visitSingularFixed32Field(value: self.flags, fieldNumber: 8)
    }
    if !self.traceID.isEmpty {
      try visitor.visitSingularBytesField(value: self.traceID, fieldNumber: 9)
    }
    if !self.spanID.isEmpty {
      try visitor.visitSingularBytesField(value: self.spanID, fieldNumber: 10)
    }
    if self.observedTimeUnixNano != 0 {
      try visitor.visitSingularFixed64Field(value: self.observedTimeUnixNano, fieldNumber: 11)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  package static func ==(lhs: Opentelemetry_Proto_Logs_V1_LogRecord, rhs: Opentelemetry_Proto_Logs_V1_LogRecord) -> Bool {
    if lhs.timeUnixNano != rhs.timeUnixNano {return false}
    if lhs.observedTimeUnixNano != rhs.observedTimeUnixNano {return false}
    if lhs.severityNumber != rhs.severityNumber {return false}
    if lhs.severityText != rhs.severityText {return false}
    if lhs._body != rhs._body {return false}
    if lhs.attributes != rhs.attributes {return false}
    if lhs.droppedAttributesCount != rhs.droppedAttributesCount {return false}
    if lhs.flags != rhs.flags {return false}
    if lhs.traceID != rhs.traceID {return false}
    if lhs.spanID != rhs.spanID {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
#endif

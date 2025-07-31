//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2025 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Dispatch.DispatchWallTime
import NIOConcurrencyHelpers
package import W3CTraceContext

/// Generates trace and span ids using a `RandomNumberGenerator` in an X-Ray compatible format.
///
/// - SeeAlso: [AWS X-Ray: Tracing header](https://docs.aws.amazon.com/xray/latest/devguide/xray-concepts.html#xray-concepts-tracingheader)
package struct OTelXRayIDGenerator<NumberGenerator: RandomNumberGenerator & Sendable>: OTelIDGenerator {
    private let getCurrentSecondsSinceEpoch: @Sendable () -> UInt32
    private let randomNumberGenerator: NIOLockedValueBox<NumberGenerator>

    package init(
        randomNumberGenerator: NumberGenerator,
        getCurrentSecondsSinceEpoch: @escaping @Sendable () -> UInt32
    ) {
        self.randomNumberGenerator = .init(randomNumberGenerator)
        self.getCurrentSecondsSinceEpoch = getCurrentSecondsSinceEpoch
    }

    package func nextTraceID() -> TraceID {
        var traceIDBytes = TraceID.Bytes((0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        withUnsafeMutableBytes(of: &traceIDBytes) { ptr in
            ptr.storeBytes(of: self.getCurrentSecondsSinceEpoch().bigEndian, as: UInt32.self)
            ptr.storeBytes(
                of: randomNumberGenerator.withLockedValue { $0.next(upperBound: UInt32.max) }.bigEndian,
                toByteOffset: 4,
                as: UInt32.self
            )
            ptr.storeBytes(
                of: randomNumberGenerator.withLockedValue { $0.next(upperBound: UInt64.max) }.bigEndian,
                toByteOffset: 8,
                as: UInt64.self
            )
        }
        return TraceID(bytes: traceIDBytes)
    }

    package func nextSpanID() -> SpanID {
        var spanIDBytes = SpanID.Bytes((0, 0, 0, 0, 0, 0, 0, 0))
        withUnsafeMutableBytes(of: &spanIDBytes) { ptr in
            ptr.storeBytes(of: randomNumberGenerator.withLockedValue { $0.next() }.bigEndian, as: UInt64.self)
        }
        return SpanID(bytes: spanIDBytes)
    }
}

extension DispatchWallTime {
    fileprivate var secondsSinceEpoch: UInt32 {
        let seconds = Int64(bitPattern: self.rawValue) / -1_000_000_000
        return UInt32(seconds)
    }
}

extension OTelXRayIDGenerator where NumberGenerator == SystemRandomNumberGenerator {
    package init() {
        self.init(
            randomNumberGenerator: SystemRandomNumberGenerator(),
            getCurrentSecondsSinceEpoch: {
                DispatchWallTime.now().secondsSinceEpoch
            }
        )
    }
}

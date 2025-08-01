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
import W3CTraceContext

/// The default ID generator,
/// based on a [`RandomNumberGenerator`](https://developer.apple.com/documentation/swift/randomnumbergenerator).
struct OTelRandomIDGenerator<NumberGenerator: RandomNumberGenerator & Sendable>: OTelIDGenerator {
    private let randomNumberGenerator: NIOLockedValueBox<NumberGenerator>

    /// Create a random ID generator with a given random number generator.
    ///
    /// - Parameter randomNumberGenerator: The random number generator, defaults to
    /// [`SystemRandomNumberGenerator`](https://developer.apple.com/documentation/swift/systemrandomnumbergenerator)
    init(randomNumberGenerator: NumberGenerator) {
        self.randomNumberGenerator = NIOLockedValueBox(randomNumberGenerator)
    }

    func nextTraceID() -> TraceID {
        randomNumberGenerator.withLockedValue { .random(using: &$0) }
    }

    func nextSpanID() -> SpanID {
        randomNumberGenerator.withLockedValue { .random(using: &$0) }
    }
}

extension OTelRandomIDGenerator where NumberGenerator == SystemRandomNumberGenerator {
    init() {
        randomNumberGenerator = NIOLockedValueBox(SystemRandomNumberGenerator())
    }
}

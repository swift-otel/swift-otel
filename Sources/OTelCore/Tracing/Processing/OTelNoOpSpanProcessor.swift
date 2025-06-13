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

import ServiceContextModule

/// A span processor that ignores all operations, used when no spans should be processed.
package struct OTelNoOpSpanProcessor: OTelSpanProcessor, CustomStringConvertible {
    package let description = "OTelNoOpSpanProcessor"

    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    /// Initialize a no-op span processor.
    package init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    package func run() async {
        for await _ in stream.cancelOnGracefulShutdown() {}
    }

    package func onStart(_ span: OTelSpan, parentContext: ServiceContext) {
        // no-op
    }

    package func onEnd(_ span: OTelFinishedSpan) {
        // no-op
    }

    package func forceFlush() async throws {
        // no-op
    }
}

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

package final class TestClock: Clock, @unchecked Sendable {
    package struct Instant: InstantProtocol {
        package var offset: Duration

        package init(offset: Duration = .zero) {
            self.offset = offset
        }

        package func advanced(by duration: Duration) -> Self {
            .init(offset: offset + duration)
        }

        package func duration(to other: Self) -> Duration {
            other.offset - offset
        }

        package static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.offset < rhs.offset
        }

        package static func minutes(_ minutes: some BinaryInteger) -> Self {
            .init(offset: .seconds(minutes * 60))
        }

        package static func seconds(_ seconds: some BinaryInteger) -> Self {
            .init(offset: .seconds(seconds))
        }

        package static func milliseconds(_ milliseconds: some BinaryInteger) -> Self {
            .init(offset: .milliseconds(milliseconds))
        }

        package static func microseconds(_ microseconds: some BinaryInteger) -> Self {
            .init(offset: .microseconds(microseconds))
        }

        package static func nanoseconds(_ nanoseconds: some BinaryInteger) -> Self {
            .init(offset: .nanoseconds(nanoseconds))
        }
    }

    package var minimumResolution: Duration = .zero
    package var now: Instant {
        state.withLockedValue { $0.now }
    }

    struct State {
        // We should use a Heap here
        var continuations: [(id: UInt64, deadline: Instant, continuation: CheckedContinuation<Void, Error>)]
        var now: Instant
    }

    package let sleepCalls: AsyncStream<Void>
    private let sleepCallsContinuation: AsyncStream<Void>.Continuation

    private let state = NIOLockedValueBox(State(continuations: [], now: .init()))

    package init(now: Instant = .init()) {
        state.withLockedValue { $0.now = now }
        let (stream, continunation) = AsyncStream<Void>.makeStream()
        sleepCalls = stream
        sleepCallsContinuation = continunation
    }

    package func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                enum Action {
                    case shouldResume, shouldCancel, none
                }
                let action = self.state.withLockedValue { state -> Action in
                    guard !Task.isCancelled else {
                        return .shouldCancel
                    }
                    guard deadline > state.now else {
                        return .shouldResume
                    }
                    let id = UInt64.random(in: .min ..< .max)
                    state.continuations.append((id, deadline, continuation))
                    return .none
                }
                switch action {
                case .shouldResume:
                    continuation.resume()
                case .shouldCancel:
                    continuation.resume(throwing: CancellationError())
                case .none:
                    break
                }
                sleepCallsContinuation.yield()
            }
        } onCancel: {
            let continuations = self.state.withLockedValue { state in
                let continutations = state.continuations
                state.continuations.removeAll()
                return continutations
            }
            for entry in continuations {
                entry.continuation.resume(throwing: CancellationError())
            }
        }
    }

    package func advance(by duration: Duration = .zero) {
        let continuationsToResume = state.withLockedValue { state in
            let deadline = state.now.advanced(by: duration)
            precondition(state.now < deadline)
            state.now = deadline

            let continuationsToResume = state.continuations.filter { $0.deadline <= deadline }
            state.continuations.removeAll { $0.deadline <= deadline }
            return continuationsToResume
        }
        for entry in continuationsToResume {
            entry.continuation.resume()
        }
    }

    package func advance(to deadline: Instant) {
        let continuationsToResume = state.withLockedValue { state in
            precondition(state.now < deadline)
            state.now = deadline

            let continuationsToResume = state.continuations.filter { $0.deadline <= deadline }
            state.continuations.removeAll { $0.deadline <= deadline }
            return continuationsToResume
        }
        for entry in continuationsToResume {
            entry.continuation.resume()
        }
    }
}

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

final class TestClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration

        init(offset: Duration = .zero) {
            self.offset = offset
        }

        func advanced(by duration: Duration) -> Self {
            .init(offset: offset + duration)
        }

        func duration(to other: Self) -> Duration {
            other.offset - offset
        }

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.offset < rhs.offset
        }

        static func minutes(_ minutes: some BinaryInteger) -> Self {
            .init(offset: .seconds(minutes * 60))
        }

        static func seconds(_ seconds: some BinaryInteger) -> Self {
            .init(offset: .seconds(seconds))
        }

        static func milliseconds(_ milliseconds: some BinaryInteger) -> Self {
            .init(offset: .milliseconds(milliseconds))
        }

        static func microseconds(_ microseconds: some BinaryInteger) -> Self {
            .init(offset: .microseconds(microseconds))
        }

        static func nanoseconds(_ nanoseconds: some BinaryInteger) -> Self {
            .init(offset: .nanoseconds(nanoseconds))
        }
    }

    var minimumResolution: Duration = .zero
    var now: Instant {
        state.withLockedValue { $0.now }
    }

    struct State {
        // We should use a Heap here
        var continuations: [(id: UInt64, deadline: Instant, continuation: CheckedContinuation<Void, Error>)]
        var now: Instant
    }

    let sleepCalls: AsyncStream<Void>
    private let sleepCallsContinuation: AsyncStream<Void>.Continuation

    private let state = NIOLockedValueBox(State(continuations: [], now: .init()))

    init(now: Instant = .init()) {
        state.withLockedValue { $0.now = now }
        let (stream, continunation) = AsyncStream<Void>.makeStream()
        sleepCalls = stream
        sleepCallsContinuation = continunation
    }

    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
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

    func advance(by duration: Duration = .zero) {
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

    func advance(to deadline: Instant) {
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

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

struct TimeoutError: Error {
    var underlyingError: any Error
}

func withTimeout<T: Sendable>(
    _ timeout: Duration,
    isolation: isolated(any Actor)? = #isolation,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withTimeout(timeout, clock: ContinuousClock(), operation: operation)
}

func withTimeout<T: Sendable, Clock: _Concurrency.Clock>(
    _ timeout: Clock.Duration,
    clock: Clock,
    isolation: isolated(any Actor)? = #isolation,
    operation: @escaping () async throws -> T
) async throws -> T {
    nonisolated(unsafe) let operation = { operation }
    let result: Result<T, any Error> = await withTaskGroup(of: TaskResult<T>.self) { group in
        let operation = operation()
        group.addTask {
            do {
                try await clock.sleep(for: timeout, tolerance: .zero)
                return .timedOut
            } catch {
                return .cancelled
            }
        }
        group.addTask {
            do {
                return try await .success(operation())
            } catch {
                return .error(error)
            }
        }

        switch await group.next() {
        case .success(let result):
            // Work returned a result. Cancel the timer task and return
            group.cancelAll()
            return .success(result)
        case .error(let error):
            // Work threw. Cancel the timer task and rethrow
            group.cancelAll()
            return .failure(error)
        case .timedOut:
            // Timed out, cancel the work task.
            group.cancelAll()

            switch await group.next() {
            case .success(let result):
                return .success(result)
            case .error(let error):
                return .failure(TimeoutError(underlyingError: error))
            case .timedOut, .cancelled, .none:
                // We already got a result from the sleeping task so we can't get another one or none.
                preconditionFailure("Unexpected task result")
            }
        case .cancelled:
            switch await group.next() {
            case .success(let result):
                return .success(result)
            case .error(let error):
                return .failure(TimeoutError(underlyingError: error))
            case .timedOut, .cancelled, .none:
                // We already got a result from the sleeping task so we can't get another one or none.
                preconditionFailure("Unexpected task result")
            }
        case .none:
            preconditionFailure("Unexpected task result")
        }
    }
    return try result.get()
}

private enum TaskResult<T: Sendable>: Sendable {
    case success(T)
    case error(any Error)
    case timedOut
    case cancelled
}

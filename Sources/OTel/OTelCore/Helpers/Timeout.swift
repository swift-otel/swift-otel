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

package func withTimeout<ClockType: Clock, ChildTaskResult>(
    _ timeout: ClockType.Duration,
    priority: TaskPriority? = nil,
    clock: ClockType,
    operation: @escaping @Sendable () async throws -> ChildTaskResult
) async rethrows -> ChildTaskResult where ChildTaskResult: Sendable {
    try await withThrowingTaskGroup(of: ChildTaskResult.self) { group in
        group.addTask(priority: priority) {
            try await clock.sleep(for: timeout)
            throw CancellationError()
        }
        group.addTask(priority: priority, operation: operation)
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

package func withTimeout<ChildTaskResult>(
    _ timeout: Duration,
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async throws -> ChildTaskResult
) async rethrows -> ChildTaskResult where ChildTaskResult: Sendable {
    try await withTimeout(timeout, priority: priority, clock: ContinuousClock(), operation: operation)
}

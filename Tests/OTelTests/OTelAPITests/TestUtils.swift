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

import Testing

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported runtime")
#endif

import struct Foundation.URL
import ServiceLifecycle

extension Testing.Test {
    /// Update the `LLVM_PROFILE_PATH` with per-process pattern.
    ///
    /// This is used to work around the following bug:
    ///
    /// _Multiple exit tests corrupt coverage profdata, leading to test command failure, even with `.serialized`_ [(swift-testing#1200)][0]
    ///
    /// There's a proposed fix here:
    ///
    /// _Add `%p` to `LLVM_PROFILE_FILE` pattern when running tests with coverage_ [(swift-package-manager#8894)][1]
    ///
    /// Until a fix is avaiable, this function should be called before a call to `#expect(processExitsWith:_:)`. Likely
    /// the best place would be in the initializer of a Suite that contains an exit test.
    ///
    /// Aside: we cannot wrap `#expect(processExitsWith:_:)` due to an unrelated compiler bug, [swift#82783][2].
    ///
    /// [0]: https://github.com/swiftlang/swift-testing/issues/1200
    /// [1]: https://github.com/swiftlang/swift-package-manager/pull/8894
    /// [2]: https://github.com/swiftlang/swift/issues/82783
    static func workaround_SwiftTesting_1200() {
        let key = "LLVM_PROFILE_FILE"
        let profrawExtension = "profraw"
        guard let previousValueCString = getenv(key) else { return }
        let previousValue = String(cString: previousValueCString)
        let previousPath = URL(filePath: previousValue)
        guard previousPath.pathExtension == profrawExtension else { return }
        guard !previousPath.lastPathComponent.contains("%p") else { return }
        let newPath = previousPath.deletingPathExtension().appendingPathExtension("%p").appendingPathExtension(profrawExtension)
        let newValue = newPath.path(percentEncoded: false)
        print("Replacing \(key)=\(previousValue) with \(key)=\(newValue)")
        setenv(key, newValue, 1)
    }
}

/// Wraps a service to provide a signal when its run method has been called.
struct ServiceWrapper: Service {
    var service: any Service
    private var _runCalled = AsyncStream.makeStream(of: Void.self)
    var runCalled: Void { get async { await _runCalled.stream.first { true } } }
    init(service: any Service) { self.service = service }
    func run() async throws {
        _runCalled.continuation.yield()
        try await service.run()
    }
}

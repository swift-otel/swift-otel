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

import ServiceLifecycle

extension OTel {
    public static func bootstrap(configuration: Configuration = .default) throws -> some Service {
        throw NotImplementedError()
        // The following placeholder code exists only to type check the opaque return type.
        let service: ServiceGroup! = nil
        return service
    }
}

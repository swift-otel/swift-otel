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

struct Attribute: Equatable, Hashable, Sendable {
    var key: String
    var value: String
}

extension Set<Attribute> {
    init(_ attributes: [(String, String)]) {
        self.init(attributes.map { .init(key: $0.0, value: $0.1) })
    }
}

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
import OTelCore
import SwiftProtobuf

final class OTLPHTTPExporter: Sendable {
    init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {}

    func send(_ proto: Message) async throws {
        // TODO:
    }

    func forceFlush() async throws {
        // TODO:
    }

    func shutdown() async {
        // TODO:
    }
}

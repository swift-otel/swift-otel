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

extension OTLPGRPCMetricExporterConfiguration {
    init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        try self.init(
            environment: [:],
            endpoint: configuration.endpoint,
            shouldUseAnInsecureConnection: configuration.insecure,
            headers: .init(configuration.headers)
        )
    }
}

extension OTLPGRPCSpanExporterConfiguration {
    init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        try self.init(
            environment: [:],
            endpoint: configuration.endpoint,
            shouldUseAnInsecureConnection: configuration.insecure,
            headers: .init(configuration.headers)
        )
    }
}

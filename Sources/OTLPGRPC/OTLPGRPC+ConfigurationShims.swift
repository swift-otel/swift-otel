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

extension OTLPGRPCMetricExporterConfiguration {
    package init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        try self.init(
            environment: [:],
            endpoint: configuration.endpoint,
            shouldUseAnInsecureConnection: configuration.insecure,
            headers: .init(configuration.headers)
        )
    }
}

extension OTLPGRPCMetricExporter {
    package convenience init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        try self.init(configuration: .init(configuration: configuration))
    }
}

extension OTLPGRPCSpanExporterConfiguration {
    package init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        try self.init(
            environment: [:],
            endpoint: configuration.endpoint,
            shouldUseAnInsecureConnection: configuration.insecure,
            headers: .init(configuration.headers)
        )
    }
}

extension OTLPGRPCSpanExporter {
    package convenience init(configuration: OTel.Configuration.OTLPExporterConfiguration) throws {
        try self.init(configuration: .init(configuration: configuration))
    }
}

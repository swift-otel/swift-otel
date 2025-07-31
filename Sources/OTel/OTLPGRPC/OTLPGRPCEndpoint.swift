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

import struct Foundation.URL

struct OTLPGRPCEndpoint: Equatable {
    let host: String
    let port: Int
    let isInsecure: Bool

    init(host: String, port: Int, isInsecure: Bool) {
        self.host = host
        self.port = port
        self.isInsecure = isInsecure
    }

    init(urlString: String, isInsecure: Bool?) throws {
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            // TODO: Log
            self = .default
            return
        }

        if let host = url.host,
           let port = url.port,
           let scheme = url.scheme
        {
            self.host = host
            self.port = port
            self.isInsecure = scheme != "https"
        } else {
            // Foundation.URL without scheme doesn't expose host/port so we split it manually
            let urlStringComponents = urlString.split(separator: ":")
            guard urlStringComponents.count == 2,
                  let port = Int(urlStringComponents[1])
            else {
                // TODO: Log
                throw OTLPGRPCEndpointConfigurationError(value: urlString)
            }
            self = OTLPGRPCEndpoint(
                host: String(urlStringComponents[0]),
                port: port,
                isInsecure: isInsecure ?? false
            )
        }
    }

    static let `default` = OTLPGRPCEndpoint(host: "localhost", port: 4317, isInsecure: true)
}

struct OTLPGRPCEndpointConfigurationError: Error {
    let value: String
}

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

import CoreMetrics
import Logging
import OTelCore
import ServiceLifecycle
import Tracing
#if OTLPGRPC
    import OTLPGRPC
#endif
#if OTLPHTTP
    import OTLPHTTP
#endif

extension OTel {
    public static func makeLoggingBackend(configuration: OTel.Configuration = .default) throws -> (factory: @Sendable (String) -> any LogHandler, service: some Service) {
        throw NotImplementedError()
        // The following placeholder code exists only to type check the opaque return type.
        let factory: (@Sendable (String) -> any LogHandler)! = nil
        let service: ServiceGroup! = nil
        return (factory, service)
    }

    public static func makeMetricsBackend(configuration: OTel.Configuration = .default) throws -> (factory: any CoreMetrics.MetricsFactory, service: some Service) {
        throw NotImplementedError()
        // The following placeholder code exists only to type check the opaque return type.
        let factory: (any CoreMetrics.MetricsFactory)! = nil
        let service: ServiceGroup! = nil
        return (factory, service)
    }

    public static func makeTracingBackend(configuration: OTel.Configuration = .default) throws -> (factory: any Tracing.Tracer, service: some Service) {
        throw NotImplementedError()
        // The following placeholder code exists only to type check the opaque return type.
        let factory: (any Tracing.Tracer)! = nil
        let service: ServiceGroup! = nil
        return (factory, service)
    }
}

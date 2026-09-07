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

import GRPCCore
import GRPCNIOTransportHTTP2Posix
import NIOConcurrencyHelpers
import OTel
import SwiftProtobuf
import XCTest

@available(gRPCSwift, *)
final class OTLPGRPCMockCollector: Sendable {
    let recordingLogsService = RecordingLogsService()
    let recordingMetricsService = RecordingMetricsService()
    let recordingTraceService = RecordingTraceService()

    @discardableResult
    static func withInsecureServer<T>(operation: (_ collector: OTLPGRPCMockCollector, _ endpoint: String) async throws -> T) async throws -> T {
        let collector = self.init()
        let server = GRPCServer(
            transport: .http2NIOPosix(address: .ipv4(host: "127.0.0.1", port: 0), transportSecurity: .plaintext),
            services: [collector.recordingLogsService, collector.recordingMetricsService, collector.recordingTraceService]
        )

        return try await withThrowingTaskGroup { group in
            group.addTask { try await server.serve() }
            let address = try await server.listeningAddress
            let port = try XCTUnwrap(address?.ipv4?.port)
            let result = try await operation(collector, "http://localhost:\(port)")
            server.beginGracefulShutdown()
            try await group.waitForAll()
            return result
        }
    }

    @discardableResult
    static func withSecureServer<T>(
        operation: (_ collector: OTLPGRPCMockCollector, _ endpoint: String, _ trustRootsPath: String) async throws -> T
    ) async throws -> T {
        try await withTemporaryDirectory { tempDir in
            let trustRootsPath = tempDir.appendingPathComponent("trust_roots.pem")
            try Data(exampleCACert.utf8).write(to: trustRootsPath)
            let certificatePath = tempDir.appendingPathComponent("server_cert.pem")
            try Data(exampleServerCert.utf8).write(to: certificatePath)
            let privateKeyPath = tempDir.appendingPathComponent("server_key.pem")
            try Data(exampleServerKey.utf8).write(to: privateKeyPath)

            let transportSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .tls(
                certificateChain: [.file(path: certificatePath.path(), format: .pem)],
                privateKey: .file(path: privateKeyPath.path(), format: .pem)
            )

            let collector = self.init()
            let server = GRPCServer(
                transport: .http2NIOPosix(address: .ipv4(host: "127.0.0.1", port: 0), transportSecurity: transportSecurity),
                services: [collector.recordingMetricsService, collector.recordingTraceService]
            )
            return try await withThrowingTaskGroup { group in
                group.addTask { try await server.serve() }
                let address = try await server.listeningAddress
                let port = try XCTUnwrap(address?.ipv4?.port)
                let result = try await operation(collector, "https://localhost:\(port)", trustRootsPath.path())
                server.beginGracefulShutdown()
                try await group.waitForAll()
                return result
            }
        }
    }
}

@available(gRPCSwift, *)
final class RecordingService<Request, Response>: Sendable where Request: Message, Response: Message {
    struct RecordedRequest {
        var message: Request
        var context: ServerContext
        var metadata: Metadata
    }

    private let recordedRequestsBox = NIOLockedValueBox<[RecordedRequest]>([])
    private let queuedErrorsBox = NIOLockedValueBox<[RPCError]>([])
    var requests: [RecordedRequest] {
        get { recordedRequestsBox.withLockedValue { $0 } }
        set { recordedRequestsBox.withLockedValue { $0 = newValue } }
    }

    /// Enqueue an `RPCError` to be thrown for the next incoming request. Errors are consumed FIFO; any request that
    /// arrives with an empty queue receives a default success response.
    func enqueueError(_ error: RPCError) {
        queuedErrorsBox.withLockedValue { $0.append(error) }
    }

    func export(request: ServerRequest<Request>, context: ServerContext) async throws -> ServerResponse<Response> {
        recordedRequestsBox.withLockedValue {
            $0.append(RecordedRequest(message: request.message, context: context, metadata: request.metadata))
        }
        let queuedError = queuedErrorsBox.withLockedValue { errors -> RPCError? in
            errors.isEmpty ? nil : errors.removeFirst()
        }
        if let queuedError {
            throw queuedError
        }
        return ServerResponse(message: Response())
    }
}

@available(gRPCSwift, *)
final class RecordingTraceService: Opentelemetry_Proto_Collector_Trace_V1_TraceService.ServiceProtocol {
    typealias Request = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest
    typealias Response = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse
    let recordingService = RecordingService<Request, Response>()
    func export(request: ServerRequest<Request>, context: ServerContext) async throws -> ServerResponse<Response> {
        try await recordingService.export(request: request, context: context)
    }
}

@available(gRPCSwift, *)
final class RecordingMetricsService: Opentelemetry_Proto_Collector_Metrics_V1_MetricsService.ServiceProtocol {
    typealias Request = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest
    typealias Response = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse
    let recordingService = RecordingService<Request, Response>()
    func export(request: ServerRequest<Request>, context: ServerContext) async throws -> ServerResponse<Response> {
        try await recordingService.export(request: request, context: context)
    }
}

@available(gRPCSwift, *)
final class RecordingLogsService: Opentelemetry_Proto_Collector_Logs_V1_LogsService.ServiceProtocol {
    typealias Request = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest
    typealias Response = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse
    let recordingService = RecordingService<Request, Response>()
    func export(request: ServerRequest<Request>, context: ServerContext) async throws -> ServerResponse<Response> {
        try await recordingService.export(request: request, context: context)
    }
}

private let exampleServerCert = """
-----BEGIN CERTIFICATE-----
MIIFljCCA36gAwIBAgIUQZU66L/N0zvRZmZlzY1e0iYulxYwDQYJKoZIhvcNAQEL
BQAwUTELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAkNBMRIwEAYDVQQHDAlDdXBlcnRp
bm8xDzANBgNVBAoMBlRlc3RDQTEQMA4GA1UEAwwHVGVzdCBDQTAgFw0yNjA5MDcw
OTQ4MzVaGA8yMTI2MDgxNDA5NDgzNVowVzELMAkGA1UEBhMCVVMxCzAJBgNVBAgM
AkNBMRIwEAYDVQQHDAlDdXBlcnRpbm8xEzARBgNVBAoMClRlc3RTZXJ2ZXIxEjAQ
BgNVBAMMCWxvY2FsaG9zdDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
AJSxheeHTZkE+qf19NkUokYOC31ovpb8cZLzNokFfR8/Lamih4OuFXYdnMm/ZhwL
FFKKitGGoZUogdZgwnbwEnVaG9szG2g6smXfPNVs7dmfD8RwnozhlhiY7CQ7+FvQ
a7+zHkYEKsqsVaVJFn5UyKBosmRhxL3jag28R5l+1bZiIPMalCtSMzo1jjeInQ/7
/Vf1fKCPCvMVpM8j8nhr8oVdCxbGKGCCwcPYilVPryhLVtC1AE3zPLFsfKC5Weil
6w+mOgJNT7tFEBqTd/PworVh/HV4oTdgghXJ3jwCfyDPDPDfFHM7jfM9PAZJl/lr
qynH2cWcu2rxNHNQUddxS4yqIlCfcgHYVqliroD1lwRh/5uXuiNO+YAzDNZvD293
JMicglx7pWf/fKFjcmlGpKUUQf7LY9W5+whcjAtAG4dN7H5GBWYGTaFiKKOqNueM
ZZX7+CROzV2V/JyM2/7Yg6WAFvdZ1acvpeGd3rboZEgL93/KrFv/QLMm4AGe0Yke
ZI7EIPYzszoWFoz0I5R/c7ROaM1jI1LoiBlD82U/1ajB5vv6w8kx8+KlQ2dN3o1r
jqKNAdaigQtpmQxoFpZ/7cS0+FtirHT3GkGpspwR7Qt0QIhpb3SVPWdX1HUF3Ctn
4lR6ysbB4DcqjWPs6eYZPlByvrdg6kSS23rBeOYwFZKBAgMBAAGjXjBcMBoGA1Ud
EQQTMBGCCWxvY2FsaG9zdIcEfwAAATAdBgNVHQ4EFgQU7CNI9OXdGYGYK3fDP0ol
Zq2venEwHwYDVR0jBBgwFoAU3Apu6Wbg64uVuM6GYNE6jHIkktkwDQYJKoZIhvcN
AQELBQADggIBAAWBKv5/2In8G3Gr0ZlxWil/GQ9FzijAfeXv6w3SADkDSHJcO/UE
/Uq2rsQ1clHtFazhy0JDWRhDAdm42THksCx2ISRUME3hZPVyEm+Pbom/+mvdZgH4
WzrVNqwDXfXpiV++E8r6oQimzomI4go8mYTd3SbMbsY2P2xoSxHqdCQ1WXvy10/g
hSZsOPSmwcwqA6rD457Y3lp0934bQHT+LmbxZ/cE4gG6S+L9Mxkbnqxcn+a3VAZ8
eOlNwKFPkY5C4amtvzmX5AcJEtoJGcYvC6+8ZLHzGd9BhzppzDGkbet2RBHdiJqE
h+wE+/KZQ4iWInFyJ7SUuvqJ/OeRSC8oJS4KJE43t9Y8j570UOD+XzbujwYWxWWm
J6So0+zZC+qdFgJyyYYOanjZDdLfxQQf6W+Exn1d91tNo9zhETzDqlDe3hDPN1CZ
XHJk7656ooB8AivJS8zBgQQJMq0qP4ozTLvMaDjtqFPKjw9qnBu2jXVSHzpAtrqm
XIqT7KNDrK1wyKQUSo9d8H0MhllyEBz3AuIUjj4abrTKvIg1CkinMoH2IdMBO5qq
RAa00vXWJ7ikVGXWWkGyEXWHTg/+9kYleTjMYht2CWNoaAMsjkMuyUYjvkXTWU7U
a9xP/QCw5afjXcOSaXOF4GAQri3tlJPQYuI27sQvUX61HRIdiXQN9zZA
-----END CERTIFICATE-----
"""

private let exampleServerKey = """
-----BEGIN PRIVATE KEY-----
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
GG4U822KhKDdGpavkhH7jG5B0cGcMdZ1L50WNEUCggEAaas4rpgv6+ysjemW3ygu
3AlSwe4kDnuB7gI2ly13nDjdsEDhxP7vydG0N2Y6tSyzkTIBvl/hUrmU1qJlyBcf
EPDBtWBtnlV0GyJ8MQ+wakk/Xobf9kZuUdTlTfyFlNCZFgp1lX3z94HHlzC1IRW/
ShFD0t3TX7iCRNq/a3gpNU6jM5VmtpHz6NdyQjTing+PmabU8tvqx215hNg2lYdJ
5Kce5ymfFFml2HPSGeVzLAidXyR2J6ylWZAMYwtemLBhgKea7c2AyTNu6oAGO2hE
vYexr5O2YxN0tkQMPHNyCtXxg4s9MeZOxwwLPG67jdkNA+4gVxNqwhU02Jt6y9bu
QQKCAQEApu6GLDM/8XVAn/kjN5oxGD5VbZwurOa/0Ze2ZhJft1JP6IywPlnYwe/K
uoh+bpf0xJaNsx9slviE2hSbW2k+wt+cCLa217Pp0/OLckSLYsY0etTFntfKY4s7
m77IykJMbLmjlK1Zxeyqcmu0f74GItv7rY6x1dbz5UYJN/7waSy4RRs9AiYcqzKa
bdB8rpAHEtcmRYADUb0BOJ8SMUSBPF17GcmJgiXRQWuEfqlO/jhCBBoUHDXwGbzi
U7X2z5Z7ocUMgdk7OPj6W6ByRZZstML5SI5a2r+cNqFamUKdBHIMDDO1LAWXFDUR
ffwL/zRqY41L6SOKlv74Xdf0R9Y8bQ==
-----END PRIVATE KEY-----
"""

private let exampleCACert = """
-----BEGIN CERTIFICATE-----
MIIFhTCCA22gAwIBAgIUV6nDDelbUebBAypZ/ebQ7CwBkbQwDQYJKoZIhvcNAQEL
BQAwUTELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAkNBMRIwEAYDVQQHDAlDdXBlcnRp
bm8xDzANBgNVBAoMBlRlc3RDQTEQMA4GA1UEAwwHVGVzdCBDQTAgFw0yNjA5MDcw
OTQ4MzRaGA8yMTI2MDgxNDA5NDgzNFowUTELMAkGA1UEBhMCVVMxCzAJBgNVBAgM
AkNBMRIwEAYDVQQHDAlDdXBlcnRpbm8xDzANBgNVBAoMBlRlc3RDQTEQMA4GA1UE
AwwHVGVzdCBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOStAZUX
kZ2DFYgb5CurBiW4P0feTQrVbJRHeyxDm4SEKTqHTJyDSZ2tQ0xZMm8yAkqmIG46
jtUe1K4vE8tGISO9QfJZcHBd6+rPyXPubCwn/TQteR4wV4WjGYRKL5t/EcFE692n
JE/1mALW0gLVw0G5kXoHlcDEnvWJ9zGZd6I848zX5Hk74qruIoIPShod5DYzN6GQ
aomXMY+VwKoxnTHGAfemXZxn+1E2JRS2nQDPOWs7aP+NgHw7fVE5XbOrPAALA5Bd
UvxMfov5yMNX/qPhglXri3QL0OD6Y9+MoEtU4IVArMYJ7o5E3l8W7s2vnLOGvhYJ
nLfgEjHzGEQsmXNVzQekjknmrAqfkbcvwgBdQ7X+nx0gwfT+wrQjbcOl20Lk0e/Y
9i9KlS3+gJqNgun1vP1pICAATERnG4ap734A95GqM+RSRQzoqckrvbAzsso+9a7E
0wLyN2jb+Nm3hEHdnOYy3X9mBBHciZcaRO//k4JbgKiCImF6UqN9rdVyJkc1Lsws
Lwiz7KzWNMpPl4BCUBBzB/UZzbvneyMMkls1cpvpSp7jsB16Vjb391aadaOk7y9i
E4ne4d7OjTQpE1gqRnG45hpnLxSERwbS6kUdjDqc+r8GNeTHQ4CcJ95ieo98mZ7Y
A6TLbS8sZiTjOz4COocTs/KMbTvIirAoqjpnAgMBAAGjUzBRMB0GA1UdDgQWBBTc
Cm7pZuDri5W4zoZg0TqMciSS2TAfBgNVHSMEGDAWgBTcCm7pZuDri5W4zoZg0TqM
ciSS2TAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4ICAQB2zGbszTXp
74kSm90aXhlUPYsXRKAq8Nsl9cHpVXm558D/EWMtMfOdB64S2DI9e1Uw8UbfVhtX
AhG8V9ARQLCBtnYK2zsU8QROYxVkd5/mhAdqlQWwszzdzCPg79QGVRBs5jd7XwCK
65SLIA0s4Q0nRcIsyrjQmebDDogS1PtaGIbQqih009Eh/72MapB9r1WqOF+DYeIg
8HavGMbued7qesg4N3XS+wR+u8P6ljkticwqJWzkIT9S1NP3Ly5XI4Ty0Y4zN9fW
KQe13KygcQZDbcWsDaLb6md/sZbb0UoHDXIqROsbgx1/lyM825Q7pDYMaSmXTZJf
44kYmR/Kb9OCqAaLc5L7dd6Hu83dXYiP5V22ETaNDeYI+j00Zqsqk90J9H7kENs2
wXwdltG5G0nO4mTGtNm2tdodWz6NR1xSDceN+kN61E+TRNf21gyD7IeiVTRuHlBl
yMb42dwrXht0PwnQSad+nIlcmXp9+gUZVt4eaO+TuDNlZ0gEof4N2oAJYaYSQwJo
eB/aWOnkHmKvhIAQ/GeNojLZjyXHHczNzyWhb+lMYwFh94xpcle8e/ES6YCn+wVg
q/flDy1tNmkG8gdGltkRFgtXl1mIQ8LKtjIJeVII3Hz0cjo+0zRWLNcWL1gjLGc9
m04sbLxE9DBmzcrWjDTHDXWMTk7IwIlb1w==
-----END CERTIFICATE-----
"""

private func withTemporaryDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: false)
    defer { try! FileManager.default.removeItem(at: tempDir) }
    return try await body(tempDir)
}

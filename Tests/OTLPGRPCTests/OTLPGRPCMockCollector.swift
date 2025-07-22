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
import OTLPGRPC
import SwiftProtobuf
import XCTest

@available(gRPCSwift, *)
final class OTLPGRPCMockCollector: Sendable {
    let recordingMetricsService = RecordingMetricsService()
    let recordingTraceService = RecordingTraceService()

    @discardableResult
    static func withInsecureServer<T>(operation: (_ collector: OTLPGRPCMockCollector, _ endpoint: String) async throws -> T) async throws -> T {
        let collector = self.init()
        let server = GRPCServer(
            transport: .http2NIOPosix(address: .ipv4(host: "127.0.0.1", port: 0), transportSecurity: .plaintext),
            services: [collector.recordingMetricsService, collector.recordingTraceService]
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
    var requests: [RecordedRequest] {
        get { recordedRequestsBox.withLockedValue { $0 } }
        set { recordedRequestsBox.withLockedValue { $0 = newValue } }
    }

    func export(request: ServerRequest<Request>, context: ServerContext) async throws -> ServerResponse<Response> {
        requests.append(RecordedRequest(message: request.message, context: context, metadata: request.metadata))
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

private let exampleServerCert = """
-----BEGIN CERTIFICATE-----
MIICmjCCAYICAQEwDQYJKoZIhvcNAQELBQAwEjEQMA4GA1UEAwwHc29tZS1jYTAe
Fw0yNDA3MjkxMzUxMDVaFw0yNTA3MjkxMzUxMDVaMBQxEjAQBgNVBAMMCWxvY2Fs
aG9zdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMJH2M/mJGXZneOE
5UWbicTg1BxkdNND50p0fO/35CG4jDQ3CekXUuQ6kK6ZJ2idDQTOWJqd/jSB7Ctc
zmZ9KBAfhP9PHMZQaVQSo+tpvX6vC/hw3PCOEne1l8H8O957hBdOhEDg1crAZ33M
cTOtxTSNw7hh0OXzLyOTfq6h3nHyvjuj82fn8nyJ9lARDZ8grdLS5LVE+Je1G3My
kXJKJoYCGQHGDKmj7o1nrwiii20uE0gnjwGEiTO1ngKQGXzL6guuR1bMmE1UIPD7
IySu8Yg2nI8YB96dVNFaiB7gJg9Nde7a7GHPh+4t0NSqLlBL+k94c2J8lWgN38bZ
ugoknf0CAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAXmSnx5fjn0Z9GLQYkaXxKUoc
rYPkmzRCocso3GNMWz3kde351UmPpX3tf11638aIKO0xzJ6PZyYowdbCXZs4Co/o
pYyeW2LOoxLwSBF8wFMAPN3FB54c/KfancXGV1ULTlhfpnoZvUPnqJDYoxFRUkIQ
wVtlyA/p5Zfc9U8czer42eo5aj9D9ircBt4k6hx9IY99YvyNeFfMq4TLOgJZkZT7
2AImVq4kBvIUVrK86MGyRuNbAWP4fY5OOymT0rEKA6U5Lx+c9PPaFgozbGk4QAMB
ZTwv8ymHAKdcgiDRAoQ2NhkSlySnKi4oEwcKLYPuyrpt1eG2Lx993gdSa4z2eQ==
-----END CERTIFICATE-----
"""

private let exampleServerKey = """
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAwkfYz+YkZdmd44TlRZuJxODUHGR000PnSnR87/fkIbiMNDcJ
6RdS5DqQrpknaJ0NBM5Ymp3+NIHsK1zOZn0oEB+E/08cxlBpVBKj62m9fq8L+HDc
8I4Sd7WXwfw73nuEF06EQODVysBnfcxxM63FNI3DuGHQ5fMvI5N+rqHecfK+O6Pz
Z+fyfIn2UBENnyCt0tLktUT4l7UbczKRckomhgIZAcYMqaPujWevCKKLbS4TSCeP
AYSJM7WeApAZfMvqC65HVsyYTVQg8PsjJK7xiDacjxgH3p1U0VqIHuAmD0117trs
Yc+H7i3Q1KouUEv6T3hzYnyVaA3fxtm6CiSd/QIDAQABAoIBAA7RuikJjgcy1UdQ
kMiBd73LxIIx63Nd/5t/TTRkvUMRN6iX9iqQe+Mq0HRw/D+Pkzmln76ThJtuuZwJ
JTlOHKs2LEfpOfGqmo4uKdDALRMnuQsHWOMEg0YcVOoYGlz7IPVCKPZl8AjaKkq/
OHdPrvY2RhKfa3bO2O6mxof9kuEwF90l+CjxAcKd4GGMFE+tUjfCxveA02eDHAgm
dwgUGDKFLzgiOgKeBjh9kdLP181o3b5jHVqaw5ZkekYSS7KdLZr9dl1qbJ7xFhbj
Jnls98aQ3Kn4zF+LJex44Zf5R/9Gfxul9QtGIyNJtsGhsmF9j+9POqRGyFfyiu9x
guJ7sqECgYEA6+IwRW7wfjXzTSukhKzb385g8P+UiIghNHW8OSiVBR2mOhbRtvZd
+qi35WXK5mr4cK2jrrU0v5Ddvs10xlMyPUkxIOrwsBw/OdPKzRfg+uaei8ldI+ue
tYjnL2hoDVZxMUX0cX7Kju6MUWkf6R3J75av51AVVcvWtSSRu4hVqIUCgYEA0tli
M3txGAOfxrhYxmk/vYYB3eE6gVpEZWo1F/3BnJaH7MeLmjpC/aXp5Srs0GwG31Nx
TNO0nFu1ech17XatlZqk0eEkKau+w/wyd+v0xTy6d49SMvL3yY0H9I2O/TGWwZr3
wO45pZtEML5S6VEIPf1lj20GEiY7oLm2cBd3VRkCgYEAoPCr9MPTzJkszstnLarv
Pg2GsQgApQMUfMGT0f/xZRMstleZcNc5meuBxT+lp3720ZJ3qp0yRz4lPaja8vIS
xiPpJEeIPvCW5vKtXS/crfOp20Bhjz+VAtFMw1jeHbOL+Y18Ue+rbsgt7uHmBtzv
ScwraoyGcgppDSDNWgGUSC0CgYAkpdISvq7ujJq10I7llZ+Vkng6l44ys3zV37rw
u5NuYx+nARv7p4rDSZY41dgpdc1P/dHgl5952drWGwicSJdtPF7PeAFwGMDkka43
99QogCCs7UVNQ7vb1V5/nCcxTPA2IHhVmVJ9vVoB2uLQWNxE4glH/5whhXGxwvW5
z+pW6QKBgQDn1kRJ+Y98UpDWKdG/7NLsSkHL+Nkf8GXu66fl435Pys5U44oTDNcu
jMDtymBg0IE3lng1WbNILV7O9r9OKt1HH4L7eepzKJLP93PbpLneBlHQG9LvJmsD
3ErhTxSu80oglR1Hy2UjL70cE1nPUUpUr8yciey0G1tbnxvsWIqGtQ==
-----END RSA PRIVATE KEY-----
"""

private let exampleCACert = """
-----BEGIN CERTIFICATE-----
MIICoDCCAYgCCQCu3t2RYSXASjANBgkqhkiG9w0BAQsFADASMRAwDgYDVQQDDAdz
b21lLWNhMB4XDTI0MDcyOTEzNTEwNVoXDTI1MDcyOTEzNTEwNVowEjEQMA4GA1UE
AwwHc29tZS1jYTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOtVwFmJ
Znuf0gC8tZSVasYrSbiDiYGUJd701SskU+RbzNZl7paYIBcM2iAy4L6S2w02ehfa
RZoatGoKKhTZnyMu9NAYM1xAGiODfqC0s467udVBU6J2rU8olhm1ChZqfVBxcd9y
AF7VjvN1N3gnGM2klAWFIgqaHoFAqINwHROjycAnr40uXCLNLukkt90AmMtL5Rah
Sh0wOrx0E5OiiqWyWkjePTcMTwiRaYrUepo+EGFdmERDyiJtp5t4pcqdInJ6uA4s
eiev9NEiGdWeJy83lIdo3N777r8cK9VDsHxHGiz72ZKE35MeIEk9weC1ph81KIZV
cUDuO8nRPwWvBDUCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAT6hoeq4sJdqkaN+p
QvpF9cZ4DJLw0dFujcWQtYpPCtMVQx14QSXaPGmUG0GLVJ5mUvzV0cwUC58JDXmS
CDQ/vBnfoWQyblFQDZXOP5aDGOTmNIpFn8hutqsSDvMteh8R3zvJZBr+CQtP2Bos
TH3TcnchhKq580hYazFJJ1P4jOqBXIQb3Osnm8WjJpGuDtOP8DW2Q2AdN/8Zl+FQ
OrwiGMwghkZm2O91tYKvr45VxvyIpah36d5IFyAP7xIT4ua7X7ZyaCMjBmlK1QHd
kKUVuyR2bLgpIRpj/KQY/UOdl1zu3MUs9OkG0suPrY3EOa0K7hDkXnHjX2ZipSw7
TAuG9Q==
-----END CERTIFICATE-----
"""

private func withTemporaryDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: false)
    defer { try! FileManager.default.removeItem(at: tempDir) }
    return try await body(tempDir)
}

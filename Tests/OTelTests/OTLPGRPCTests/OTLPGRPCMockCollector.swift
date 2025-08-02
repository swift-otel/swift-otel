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
MIIFlDCCA3ygAwIBAgIUXTQ87y0IhAeaw3Xtw6C9s85dTDkwDQYJKoZIhvcNAQEL
BQAwUTELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAkNBMRIwEAYDVQQHDAlDdXBlcnRp
bm8xDzANBgNVBAoMBlRlc3RDQTEQMA4GA1UEAwwHVGVzdCBDQTAeFw0yNTA3Mjkx
NjQxNDVaFw0yNjA3MjkxNjQxNDVaMFcxCzAJBgNVBAYTAlVTMQswCQYDVQQIDAJD
QTESMBAGA1UEBwwJQ3VwZXJ0aW5vMRMwEQYDVQQKDApUZXN0U2VydmVyMRIwEAYD
VQQDDAlsb2NhbGhvc3QwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDY
mnx0eQMiVq4YWpZxcJZlvbT4Y7GwkqDm9Xef2QBXhqxKt/vytFYn+qJvkHpL6tpB
U0z7GHH+Cen3cBPBsBrVcyoR/CXuGPJ/tHoVGr2tx4FeVaiesYPTHGOpQiPFRpdr
XB+wKFxE6fglrr5gGv7xUweRUifk6LpDYrPLcEmDiaJN69EygfWEW8/04hresRsT
Omy20DeM0XQfpYJIXgXTKowpugOK+g831Avj6nCcFv+GcyVvFjIfYen8Dwllbukp
P+eC3Pq90Wkf33V4v7ABm6iBRSTA0etTla959ejfMMqT3AOOfYADue2GbDOCEaOZ
QQo7Uepi31/f8jgUw1GjVEkGFgPlyIGuNdH6JULb/Y0iI0w4ahqrIHV461LUAp68
DrEGy5nmZDPiSN8XS2SUpLhrFpi1Gg9EECqD59nYJrXja/m0Z0Vvodk9Y/2KZYIO
ys/lozxf66N2JkODMQiJbVEAvN5Fu8LDLpboztgi2jadlcclvWaNEP7GpMzDgqj8
9a8ske65WLq6hCWxRxJ+Kn7nnfc0rnmxsxKrwJZ3ll3ORRnzV/hSLrwqlMY/OCfX
V6gvUYHgXRPpYj12dq/vU+fjCe9h77cCkkzQI9qdSaVIQlrTqBwxc3LO1pkRRXwM
PA89knRPqARNPdDv0Z64kQdBt/ZxajazkQLdtHBrCwIDAQABo14wXDAaBgNVHREE
EzARgglsb2NhbGhvc3SHBH8AAAEwHQYDVR0OBBYEFI5JzUPF1+4coAG9SQZpWpJY
kZaaMB8GA1UdIwQYMBaAFLL1UhlagoZRjXJA9up6g2VODmvCMA0GCSqGSIb3DQEB
CwUAA4ICAQBoXTrazotIbedh2GkCx/B0HKZnf9VpC9b8T96xAD5kK06D8aHfjX2N
S+TWzlqLqdKNbtp2lOpMimu4om8cRKHo5cm8rP6h3VNZemCZpH/zda8CvYaYhmEx
ZAsk9iIQyqnhon9SZB2ebbvEmaZbXauMcQeboCisaf6GnsWbrJnhZT8Yr169uOg0
pkFUMVenlHljw3vW/igk4dzkhVo6Pd+AmtAvNPVBoOvruZZkKXMb5/SUT97E0dZv
7LuAWLXuCq2SDXgPSeJRUtVa3k7QM3S1fPiQiuXNdy7l6ENwYy+offB/B1hEPOED
mEcZUsgV4/UGOC81AvZ7gGABXCYwE27VTkHL14w4/n5Xaiyxe2JBZpncLO5MKsFc
eDBkGZXKq1ZdVktTAOmuMAX84Nu2Eg0qCIO0VGaUOp9Z/ZSbOmdONy6o5lSQPZPI
H5SsZ6327Ky9y4H8ycoJlJYUBXV3Wz9O7AVbVWIFzIMTXi1NjDv3gEe65h8q6vQP
AUvJt1LYYcQ6N/sl4slaPQ4V/qRhkaOHyzaJzWC538kuVL02Q2p5lqlnIkHxigaR
O8E84W0C3p/59jdFxyaPFFyisVexp4csX/E6hvjLKz79UX3612xPdgLg4wPV+jfq
P7AlwNhbtwve7j4V2T2PXfmMMPlSyJc+Ra47RxnfPk4RNMy6/FNbuQ==
-----END CERTIFICATE-----
"""

private let exampleServerKey = """
-----BEGIN PRIVATE KEY-----
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
/TIOf++iz5KcvDCk4QG5b6E/E2Jl
-----END PRIVATE KEY-----
"""

private let exampleCACert = """
-----BEGIN CERTIFICATE-----
MIIFgzCCA2ugAwIBAgIUSHFnZ4bgFFRqihcTn5yBTrD+miswDQYJKoZIhvcNAQEL
BQAwUTELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAkNBMRIwEAYDVQQHDAlDdXBlcnRp
bm8xDzANBgNVBAoMBlRlc3RDQTEQMA4GA1UEAwwHVGVzdCBDQTAeFw0yNTA3Mjkx
NjQxNDRaFw0yNjA3MjkxNjQxNDRaMFExCzAJBgNVBAYTAlVTMQswCQYDVQQIDAJD
QTESMBAGA1UEBwwJQ3VwZXJ0aW5vMQ8wDQYDVQQKDAZUZXN0Q0ExEDAOBgNVBAMM
B1Rlc3QgQ0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCciN/Sd0OM
4E6bjJfCJKOkmTIEvE2au5l3vMNcRzkqWXr94XyuGThCBA1u9HGea3MhTEtfatZv
f8QWXuSvC1PoFiTZewJ1gGF1ZxM7KGwOMjpd8JYMq4fCXMVn0ARQqQkrefQOMInS
fWVWAGY+Ua66TffdnyWdvGrMbTUNB1Pgp2I25Rj9vudaKY6vjYZ1Ozn7fMMsEKfb
FJ4C5bq8sHcE0J/nd2TMpMq93prA1kH1CVumJ9j3rzdMN5/SSoBjkQ3Uh9+KcMiU
ylomD+YmWaVSt0ijh+X2A6X0yGLhR6iG/Jcr7uhnONQwYKOgShEdGw6NuVTRMUbL
F4EmWS0Y50CZCyiCAE0ZqtTo60bZFryHxe2aqZtGpxfrO6whGmhD77Qsn5sIwsR5
56L+fjo8DiYRgcoLo7dV5LJhNJUMv6ugygGlbA77/TiNe9VwUVctePE2c5DihXJ8
brcX97LF40QfqMSFRJJJ0VdP7PLWb+MxSdzy0Nz9uP+XhBOXSn96XKdONFLydWN4
3XpwvdWqa0IfiXo6V2avmjJ73ZPcZDe6cuzlsHn+poqnwAwGgRMYb+0josvpf0AT
xGgx2rYbYp2b8blHOeZL5A/FNnHYMlDdb2WP8ldSZPsEFRdGh7pnq7xQeWKYqIh+
qxGUkQDokpX9aK/5HbXZw2zSXIxp1Ca3kwIDAQABo1MwUTAdBgNVHQ4EFgQUsvVS
GVqChlGNckD26nqDZU4Oa8IwHwYDVR0jBBgwFoAUsvVSGVqChlGNckD26nqDZU4O
a8IwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAgEAksfj65Sm23Yb
8JYew2GWK7ebFPZpgZqmt79/WjII+N2tN4mpn1l6mjF5HfaX6njAfi1X/irKc+L2
Y4+q4/VulXZBAESHnkayC2rb3st92r1qn2xguGslJrOvyo2dG9DCiCPms43kL3Z9
g0XGBkp84EC4ycezLWbUJzNM+tb11SPhPD998eQ7Su1ww6OUmeTovQ2063WPvaE7
KqZ77yNgJEBPGBvR+uMawWDFEal7aUwEZQ5p0Mtckc0FRC7OwULqzbyN4vS3PrZW
44W9IF2p5KXD8jo4o8xNF06GQHtPK/MgEdTEHIrC1KdxQC4H2Cc96xuDFeZHIKFb
G7TIU0OeBHXf/QD+NNa3MHC0ZDYAcxx74ttAPHSIvotVStlcSp9qGst07wRdWPSu
H6Bkaz5W8fHz+8fSKB0Ob2OXlNA0eJieTjVBkckSMml4zYo4cP5VxkF2mKZASVcH
tmYEKkoLBqUzPAPCMo3fTM4L384Le3eMeKp3bR2h+myA5Tl1XXlqf121j541Fyju
x2Ev5amJmVoSwEe8PtQzWXGw+K7ZEeiW60L9tnN9IOouIhU7w+r5Y9kdSvGevtbk
jVqNQztdyT00j2dK9jziOwVWR0cV+soGfNDAriVZlx1ALJrKvXc6rJa17AoLuXOR
E2bOUyB62GWj9CpqAhmj2gko7lpvFAU=
-----END CERTIFICATE-----
"""

private func withTemporaryDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: false)
    defer { try! FileManager.default.removeItem(at: tempDir) }
    return try await body(tempDir)
}

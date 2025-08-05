import Dispatch
import Logging
import NIOConcurrencyHelpers
import ServiceLifecycle
import Testing
import UnixSignals

private struct S: Service {
    var name: String
    init(_ name: String) { self.name = name }
    func run() async throws {
        print("\(name) running")
        try await gracefulShutdown()
        print("\(name) done")
    }
}

extension Logger {
    static func stderr(_ level: Logger.Level, label: String) -> Logger {
        var logger = Logger(label: label, factory: StreamLogHandler.standardError(label:))
        logger.logLevel = .debug
        return logger
    }
}

@Suite("Different ways of testing service group shutdown", .disabled())
struct ServiceLifecycleTestingFun {
    @Test("Naive run then shutdown") func testA() async throws {
        let serviceGroup = ServiceGroup(services: [S("A"), S("B")], logger: .stderr(.debug, label: "group"))
        try await withThrowingTaskGroup { group in
            group.addTask { try await serviceGroup.run() }
            await serviceGroup.triggerGracefulShutdown()
            try await group.waitForAll()
        }
    }

    @Test("Sleep then shutdown") func testB() async throws {
        let serviceGroup = ServiceGroup(services: [S("A"), S("B")], logger: .stderr(.debug, label: "group"))
        try await withThrowingTaskGroup { group in
            group.addTask { try await serviceGroup.run() }
            try await Task.sleep(for: .seconds(0.5)) // Needed to make sure the service group has called run on each service
            await serviceGroup.triggerGracefulShutdown()
            try await group.waitForAll()
        }
    }

    @Test("Wait for signal then shutdown") func testC() async throws {
        struct S_: Service {
            var name: String
            var running: AsyncStream<Void>.Continuation
            init(_ name: String, _ running: AsyncStream<Void>.Continuation) {
                self.name = name
                self.running = running
            }

            func run() async throws {
                print("\(name) running")
                running.yield()
                await AsyncStream.makeStream(of: Void.self).stream.cancelOnGracefulShutdown().first { true }
                print("\(name) done")
            }
        }

        let serviceRuns = AsyncStream.makeStream(of: Void.self)

        let serviceGroup = ServiceGroup(services: [S_("A", serviceRuns.continuation), S_("B", serviceRuns.continuation)], logger: .stderr(.debug, label: "group"))

        try await withThrowingTaskGroup { group in
            group.addTask { try await serviceGroup.run() }
            var serviceRuns = serviceRuns.stream.makeAsyncIterator()
            await serviceRuns.next()
            await serviceRuns.next()
            await serviceGroup.triggerGracefulShutdown()
            try await group.waitForAll()
        }
    }

    @Test("Wait for canary then shutdown") func testD() async throws {
        struct Canary: Service {
            private(set) var (running, continuation) = AsyncStream<Void>.makeStream(of: Void.self)
            func run() async throws {
                print("canary running")
                continuation.yield()
                await AsyncStream.makeStream(of: Void.self).stream.cancelOnGracefulShutdown().first { true }
                print("canary done")
            }
        }

        let serviceGroup = ServiceGroup(services: [S("A"), S("B")], logger: .stderr(.debug, label: "group"))
        try await withThrowingTaskGroup { group in
            let canary = Canary()
            await serviceGroup.addServiceUnlessShutdown(canary)
            group.addTask { try await serviceGroup.run() }
            await canary.running.first { true }
            await serviceGroup.triggerGracefulShutdown()
            try await group.waitForAll()
        }
    }

    @available(macOS 15.0, *)
    @Test("Wait for canary with serial executor then shutdown") func testE() async throws {
        struct Canary: Service {
            private(set) var (running, continuation) = AsyncStream<Void>.makeStream(of: Void.self)
            func run() async throws {
                print("canary running")
                continuation.yield()
                await AsyncStream.makeStream(of: Void.self).stream.cancelOnGracefulShutdown().first { true }
                print("canary done")
            }
        }

        final class DispatchSerialExecutor: TaskExecutor, SerialExecutor, @unchecked Sendable {
            private let queue = DispatchQueue(label: "DispatchSerialExecutor")

            func enqueue(_ job: consuming ExecutorJob) {
                let job = UnownedJob(job)
                queue.async { job.runSynchronously(on: self.asUnownedSerialExecutor()) }
            }
        }

        let serviceGroup = ServiceGroup(services: [S("A"), S("B")], logger: .stderr(.debug, label: "group"))
        try await withTaskExecutorPreference(DispatchSerialExecutor()) {
            try await withThrowingTaskGroup { group in
                let canary = Canary()
                await serviceGroup.addServiceUnlessShutdown(canary)
                group.addTask { try await serviceGroup.run() }
                await canary.running.first { true }
                await serviceGroup.triggerGracefulShutdown()
                try await group.waitForAll()
            }
        }
    }

    @Test("Use a custom exectuor and named tasks") func testF() async throws {
        // rdar://157558738 (We missed landing the `unsafeCurrentTask` APIs on Unowned/ExecutorJob from SE-0469)
    }
}

private final class Latch: @unchecked Sendable {
    private enum State { case waitingForFulfillment([CheckedContinuation<Void, Never>]), fulfilled }
    private var locked_state = NIOLockedValueBox(State.waitingForFulfillment([]))

    package func fulfill() {
        let continuationsToResume = locked_state.withLockedValue { state in
            switch state {
            case .fulfilled: preconditionFailure()
            case .waitingForFulfillment(let continuations):
                state = .fulfilled
                return continuations
            }
        }
        for continuation in continuationsToResume {
            continuation.resume()
        }
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            let shouldResume = locked_state.withLockedValue { state in
                switch state {
                case .fulfilled: return true
                case .waitingForFulfillment(var continuations):
                    continuations.append(continuation)
                    state = .waitingForFulfillment(continuations)
                    return false
                }
            }
            if shouldResume {
                continuation.resume()
            }
        }
    }
}

actor ServiceGroupWithRunSignal {
    private struct ServiceWrapper: Service {
        var service: any Service
        var runCalled = Latch()
        init(service: any Service) {
            self.service = service
        }

        func run() async throws {
            runCalled.fulfill()
            try await service.run()
        }
    }

    private var backing: ServiceGroup
    private var (stream, continuation) = AsyncStream.makeStream(of: Void.self)
    private var services: [ServiceWrapper] = []

    public func run(file: String = #file, line: Int = #line) async throws {
        try await backing.run(file: file, line: line)
    }

    func waitForRunning() async {
        for service in services {
            await service.runCalled.wait()
        }
    }

    public func addServiceUnlessShutdown(_ service: any Service) async {
        await addServiceUnlessShutdown(ServiceGroupConfiguration.ServiceConfiguration(service: service))
    }

    public func addServiceUnlessShutdown(_ serviceConfiguration: ServiceGroupConfiguration.ServiceConfiguration) async {
        var serviceConfiguration = serviceConfiguration
        let wrapped = ServiceWrapper(service: serviceConfiguration.service)
        serviceConfiguration.service = wrapped
        await backing.addServiceUnlessShutdown(serviceConfiguration)
    }

    public init(
        configuration: ServiceGroupConfiguration
    ) {
        var configuration = configuration
        var wrappedServices: [ServiceWrapper] = []
        configuration.services = configuration.services.map { serviceConfiguration in
            var serviceConfiguration = serviceConfiguration
            let wrapped = ServiceWrapper(service: serviceConfiguration.service)
            wrappedServices.append(wrapped)
            serviceConfiguration.service = wrapped
            return serviceConfiguration
        }
        services = wrappedServices
        backing = .init(configuration: configuration)
    }

    public init(
        services: [any Service],
        gracefulShutdownSignals: [UnixSignal] = [],
        cancellationSignals: [UnixSignal] = [],
        logger: Logger
    ) {
        let configuration = ServiceGroupConfiguration(
            services: services.map { ServiceGroupConfiguration.ServiceConfiguration(service: $0) },
            gracefulShutdownSignals: gracefulShutdownSignals,
            cancellationSignals: cancellationSignals,
            logger: logger
        )
        self.init(configuration: configuration)
    }

    public func triggerGracefulShutdown() async {
        await waitForRunning()
        await backing.triggerGracefulShutdown()
    }
}

@Test("Naive run then shutdown") func testN() async throws {
    let serviceGroup = ServiceGroupWithRunSignal(services: [S("A"), S("B")], logger: .stderr(.debug, label: "group"))
    try await withThrowingTaskGroup { group in
        group.addTask { try await serviceGroup.run() }
        await serviceGroup.triggerGracefulShutdown()
        try await group.waitForAll()
    }
}

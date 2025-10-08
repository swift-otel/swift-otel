
import ProfileRecorderSampleConversion
internal import struct NIOCore.ByteBuffer

struct OTLPProfileSampleRenderer: ProfileRecorderSampleConversionOutputRenderer {
    var aggregator: SampleAggregator = .init()

    public init() {}

    public mutating func consumeSingleSample(
        _ sample: Sample,
        configuration: ProfileRecorderSampleConversionConfiguration,
        symbolizer: CachedSymbolizer
    ) throws -> ByteBuffer {
        let symbolisedStack = try sample.stack.map { frame in
            try symbolizer.symbolise(frame)
        }
        self.aggregator.add(symbolisedStack)
        return ByteBuffer()
    }

    public mutating func finalise(
        sampleConfiguration: SampleConfig,
        configuration: ProfileRecorderSampleConversionConfiguration,
        symbolizer: CachedSymbolizer
    ) throws -> ByteBuffer {
        var stringTable: [String: StringWithID] = [:]
        for function in self.aggregator.functions.values {
            _ = stringTable.addAndGetID(function.name, type: StringWithID.self)
        }
        let samplesID = stringTable.addAndGetID("samples", type: StringWithID.self)
        let countID = stringTable.addAndGetID("count", type: StringWithID.self)
        let cpuID = stringTable.addAndGetID("cpu", type: StringWithID.self)
        let nanosecondsID = stringTable.addAndGetID("nanoseconds", type: StringWithID.self)

        let dictionary = Opentelemetry_Proto_Profiles_V1development_ProfilesDictionary.with {
            $0.stringTable = [""] + stringTable.values.sorted(by: { $0.id < $1.id }).map(\.value)

            $0.locationTable = self.aggregator.locations.values.sorted(by: { $0.id < $1.id }).map { location in
                .with {
                    $0.address = UInt64(location.id)
                    $0.line = location.functions.map { functionID in
                        .with {
                            $0.functionIndex = Int32(functionID)
                        }
                    }
                }
            }

            $0.functionTable = self.aggregator.functions.values.sorted(by: { $0.id < $1.id }).map { function in
                .with {
                    $0.filenameStrindex = Int32(function.id)
                    $0.nameStrindex = Int32(stringTable[function.name]!.id)
                }
            }
        }

        let profile = Opentelemetry_Proto_Profiles_V1development_Profile.with { profile in
            profile.sampleType = .with {
                $0.typeStrindex = Int32(samplesID)
                $0.unitStrindex = Int32(countID)
            }

            profile.sample = self.aggregator.samples.enumerated().map { index, element in
                let (_, count) = element
                return .with { outSample in
                    outSample.stackIndex = Int32(index)
                    outSample.values = [Int64(count)]
                }
            }

//            profile.sample = self.aggregator.samples.map { inSample, count in
//                .with { outSample in
//                    outSample.stackIndex = inSample.map { UInt64($0) }
//                    outSample.timestampsUnixNano = inSample.map { UInt64($0) }
//                    outSample.values = [Int64(count)]
//                }
//            }

            profile.periodType = .with {
                $0.typeStrindex = Int32(cpuID)
                $0.unitStrindex = Int32(nanosecondsID)
            }
            profile.timeUnixNano =
                (UInt64(sampleConfiguration.currentTimeSeconds) * 1_000_000_000)
                    + UInt64(sampleConfiguration.currentTimeNanoseconds)
            profile.durationNano =
                UInt64(sampleConfiguration.sampleCount) * UInt64(sampleConfiguration.microSecondsBetweenSamples) * 1000
        }

        let profilesData = Opentelemetry_Proto_Profiles_V1development_ProfilesData.with { data in
            data.dictionary = dictionary
            data.resourceProfiles = [
                .with { resourceProfile in
                    resourceProfile.resource = .with { resource in
                        resource.attributes = .init(["service_name": "FOO"])
                    }
                    resourceProfile.scopeProfiles = [
                        .with { scopeProfile in
                            scopeProfile.profiles = [profile]
                        },
                    ]
                },
            ]
        }
        let output: ByteBufferForProto = try profile.serializedBytes()

        self.aggregator = SampleAggregator()
        return output.bytes
    }
}

struct StringWithID: HasID {
    var id: Int
    var value: String

    func updatingID(_ newID: Int) -> StringWithID {
        var new = self
        new.id = newID
        return new
    }
}

import SwiftProtobuf
struct ByteBufferForProto: SwiftProtobufContiguousBytes {
    private(set) var bytes: ByteBuffer

    init(repeating: UInt8, count: Int) {
        self.bytes = ByteBuffer(repeating: repeating, count: count)
    }

    init(_ bytes: some Sequence<UInt8>) {
        self.bytes = ByteBuffer(bytes: bytes)
    }

    var count: Int {
        self.bytes.readableBytes
    }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try self.bytes.withUnsafeReadableBytes(body)
    }

    mutating func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R {
        try self.bytes.withUnsafeMutableReadableBytes(body)
    }
}

struct SampleAggregator: Sendable {
    struct Location: Sendable {
        var id: Int
        var address: UInt
        var functions: [Int]
    }

    struct Function: Sendable & HasID {
        var id: Int
        var name: String

        init(id: Int, name: String) {
            self.id = id
            self.name = name
        }

        init(id: Int, value: String) {
            self = .init(id: id, name: value)
        }

        var value: String {
            self.name
        }

        func updatingID(_ newID: Int) -> Self {
            var new = self
            new.id = newID
            return new
        }
    }

    var locations: [UInt: Location] = [:]
    var functions: [String: Function] = [:]
    var samples: [[Int]: Int] = [:]

    mutating func add(_ sample: [SymbolisedStackFrame]) {
        let locationIDs = sample.compactMap { stackFrame -> Int? in
            guard let address = stackFrame.allFrames.first?.address else {
                assertionFailure("empty stack? \(stackFrame)")
                return nil
            }

            if let location = self.locations[address] {
                return location.id
            }

            let nextID = self.locations.count + 1
            self.locations[address] = Location(
                id: nextID,
                address: address,
                functions: stackFrame.allFrames.map { frame in
                    self.functions.addAndGetID(frame.functionName, type: Function.self)
                }
            )
            return nextID
        }
        self.samples[locationIDs, default: 0] += 1
    }
}

protocol HasID: Sendable {
    var id: Int { get }

    var value: String { get }

    init(id: Int, value: String)

    func updatingID(_ newID: Int) -> Self
}

extension HasID {
    mutating func spuriousMutation() -> Self {
        self
    }
}

extension Dictionary where Key == String, Value: HasID {
    mutating func addAndGetID(_ key: Key, type: Value.Type = Value.self) -> Int {
        let nextID = self.count + 1
        return self[key, default: Value(id: nextID, value: key)].spuriousMutation().id
    }
}

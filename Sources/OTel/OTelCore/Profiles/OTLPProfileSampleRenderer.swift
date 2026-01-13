import _ProfileRecorderSampleConversion
import ProfileRecorder
internal import struct NIOCore.ByteBuffer

extension RangeReplaceableCollection {
    mutating func appendAndReturnIndex(_ element: Element) -> Index {
        let index = self.endIndex
        self.append(element)
        return index
    }

    mutating func append(_ newElement: Element, capturingIndexInto idIndex: inout [AnyHashable: Index], usingKey key: any Hashable) {
        idIndex[AnyHashable(key)] = self.appendAndReturnIndex(newElement)
    }

    // TODO: making last parameter an autoclosure causes a crash
    mutating func appendIfNotPresent<Key>(indexTable: inout [Key: Index], key: Key, _ newElement: Element) -> Index {
        if let existingIndex = indexTable[key] { return existingIndex }
        let newIndex = self.endIndex
        indexTable[key] = newIndex
        self.append(newElement)
        return newIndex
    }
}

final class OTLPProfileSampleRenderer: ProfileRecorderSampleConversionOutputRenderer, @unchecked Sendable {
    var functionTable: [String: Int] = [:]
    var stringTable: [String: Int] = [:]
    var locationTable: [UInt: Int] = [:]
    var stackTable: [[UInt]: Int] = [:]

    var dictionary: Opentelemetry_Proto_Profiles_V1development_ProfilesDictionary = .init()
    var samples: [Opentelemetry_Proto_Profiles_V1development_Sample] = []

    var resultForSwiftOTel: Opentelemetry_Proto_Profiles_V1development_ProfilesData = .init()

    fileprivate func reset() {
        self.functionTable.removeAll(keepingCapacity: true)
        self.stringTable.removeAll(keepingCapacity: true)
        self.locationTable.removeAll(keepingCapacity: true)
        self.stackTable.removeAll(keepingCapacity: true)
        self.dictionary = .init()
        self.samples = .init()
    }

    func consumeSingleSample(
        _ sample: Sample,
        configuration: ProfileRecorderSampleConversionConfiguration,
        symbolizer: CachedSymbolizer
    ) throws -> ByteBuffer {
        let stackSignature = sample.stack.map(\.stackPointer)
        let symbolisedStack = try sample.stack.map { frame in
            try symbolizer.symbolise(frame)
        }
        samples.append(.with { sample in
            sample.values = [1]
            sample.stackIndex = Int32(dictionary.stackTable.appendIfNotPresent(indexTable: &stackTable, key: stackSignature, .with { stack in
                for symbolizedFrame in symbolisedStack {
                    guard !symbolizedFrame.allFrames.isEmpty else { continue }
                    for frame in symbolizedFrame.allFrames {
                        // TODO: last parameter closure to avoid computing if already present
                        stack.locationIndices.append(Int32(dictionary.locationTable.appendIfNotPresent(indexTable: &locationTable, key: frame.address, .with { location in
                            location.address = UInt64(frame.address)
                            location.line.append(.with { line in
                                line.functionIndex = Int32(dictionary.functionTable.appendIfNotPresent(indexTable: &functionTable, key: frame.functionName, .with { function in
                                    function.nameStrindex = Int32(dictionary.stringTable.appendIfNotPresent(
                                        indexTable: &stringTable,
                                        key: frame.functionName,
                                        frame.functionName
                                    ))
                                    // TODO: mangled name can go in system_name_index
                                    if let file = frame.file {
                                        function.filenameStrindex = Int32(dictionary.stringTable.appendIfNotPresent(
                                            indexTable: &stringTable,
                                            key: file,
                                            file
                                        ))
                                    }
                                    if let line = frame.line {
                                        function.startLine = Int64(line)
                                    }
                                }))
                            })
                        })))
                    }
                }
            }))
        })

        return ByteBuffer()
    }

    func finalise(
        sampleConfiguration: SampleConfig,
        configuration: ProfileRecorderSampleConversionConfiguration,
        symbolizer: CachedSymbolizer
    ) throws -> ByteBuffer {
        let samplesID = dictionary.stringTable.appendIfNotPresent(indexTable: &stringTable, key: "samples", "samples")
        let countID = dictionary.stringTable.appendIfNotPresent(indexTable: &stringTable, key: "count", "count")
        let cpuID = dictionary.stringTable.appendIfNotPresent(indexTable: &stringTable, key: "cpuID", "cpuID")
        let nanosecondsID = dictionary.stringTable.appendIfNotPresent(indexTable: &stringTable, key: "nanoseconds", "nanoseconds")

        // hack
        dictionary.mappingTable.append(.init())

        let profile = Opentelemetry_Proto_Profiles_V1development_Profile.with { profile in
            profile.sample = samples

            profile.sampleType = .with {
                $0.typeStrindex = Int32(samplesID)
                $0.unitStrindex = Int32(countID)
            }
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

        self.resultForSwiftOTel = .with { profilesData in
            profilesData.dictionary = dictionary
            profilesData.resourceProfiles = [
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
        let output: ByteBufferWrapper = try self.resultForSwiftOTel.serializedBytes()
        self.reset()
        return output.backing
    }
}

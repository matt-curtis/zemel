//
//  Testing Helpers.swift
//  Zemel
//
//  Created by Matt Curtis on 2/22/25.
//

import Testing
import Zemel

@propertyWrapper
class CountBasedExpectation {
    
    var wrappedValue: CountBasedExpectation { self }
    
    let expectationDescription: String
    
    let expectedCount: Int
    
    let sourceLocation: SourceLocation
    
    private var count = 0
    
    init(expecting expectationDescription: String, times: Int, sourceLocation: SourceLocation = #_sourceLocation) {
        self.expectationDescription = expectationDescription
        self.expectedCount = times
        self.sourceLocation = sourceLocation
    }
    
    deinit {
        #expect(
            count == expectedCount,
            "Expected to record \(expectationDescription) \(expectedCount) times",
            sourceLocation: sourceLocation
        )
    }
    
    func record() {
        count += 1
    }
    
}

enum ChunkingStrategy: CaseIterable {
    
    case none
    case chunked
    
}

func parse<R: Routine & ~Copyable>(xml: String, chunking chunkingStrategy: ChunkingStrategy, using routine: inout R) throws {
    var zemel = Zemel()
    
    try zemel.using(&routine) {
        parse in
        
        switch chunkingStrategy {
            case .none:
                try parse(final: true, chunk: xml)
                
            case .chunked:
                let totalBytes = xml.utf8.count
                
                if totalBytes == 0 {
                    try parse(final: false, chunk: "")
                    try parse(final: true, chunk: "")
                } else {
                    let chunkSize = totalBytes <= 4 ? 1 : 4
                    
                    let chunks = stride(from: 0, to: totalBytes, by: chunkSize).map {
                        $0..<min($0 + chunkSize, totalBytes)
                    }
                    
                    do {
                        try xml.withCString {
                            for (i, chunk) in zip(0..., chunks) {
                                let isFinal = i == chunks.count - 1
                                
                                let buffer = UnsafeBufferPointer(
                                    start: $0.advanced(by: chunk.startIndex),
                                    count: chunk.endIndex - chunk.startIndex
                                )
                                
                                try parse(final: isFinal, chunk: buffer)
                            }
                        }
                    } catch {
                        throw error
                    }
                }
        }
    }
}

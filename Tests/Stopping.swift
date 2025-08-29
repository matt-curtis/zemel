//
//  Stopping.swift
//  Zemel
//
//  Created by Matt Curtis on 2/15/25.
//

import Testing
import Zemel

@Suite("Stopping")
struct StopTests {
    
    @Suite("Nested XML")
    struct NestedXML {
        
        let xml = """
        <a>
            root (a) level text
            <b>
                b-level text
                <c>
                    c-level text
                    <d>
                        d-level text
                    </d>
                </c>
            </b>
        </a>
        """
        
        @Test("Single recursive handler", arguments: ChunkingStrategy.allCases)
        func singleRecursiveHandler(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
            struct TestRoutine: Routine, ~Copyable {
                
                let ctx = context()
                
                let confirm: Confirmation
                
                mutating func body() throws -> some RoutineBody {
                    try select(descendant: "d") {
                        confirm()
                        
                        throw CancellationError()
                    }
                }
                
            }
            
            await confirmation("single descendant('d') handler is called once", expectedCount: 1) {
                confirm in
                
                _ = #expect(throws: CancellationError.self) {
                    var routine = TestRoutine(confirm: confirm)
                    
                    try parse(xml: xml, chunking: chunkingStrategy, using: &routine)
                }
            }
        }
        
        @Test("Multiple nested handlers", arguments: ChunkingStrategy.allCases)
        func multipleNestedHandlers(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
            struct TestRoutine: Routine, ~Copyable {
                
                let ctx = context()
                
                var aCount = 0, bCount = 0, cCount = 0, dCount = 0
                
                mutating func body() throws -> some RoutineBody {
                    try select("a") {
                        aCount += 1
                        
                        try select("b") {
                            bCount += 1
                            
                            try select("c") {
                                cCount += 1
                                
                                try select("d") {
                                    dCount += 1
                                    
                                    end { dCount += 1 }
                                    
                                    throw CancellationError()
                                }
                                
                                end { cCount += 1 }
                            }
                            
                            end { bCount += 1 }
                        }
                        
                        end { aCount += 1 }
                    }
                }
                
            }
            
            var routine = TestRoutine()
            
            #expect(throws: CancellationError.self) {
                try parse(xml: xml, chunking: chunkingStrategy, using: &routine)
            }
            
            #expect(routine.aCount == 1)
            #expect(routine.bCount == 1)
            #expect(routine.cCount == 1)
            #expect(routine.dCount == 1)
        }
        
    }
    
    @Suite("Recursively nested xml")
    struct RecursivelyNestedXML {
        
        let xml = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package>
            <metadata>
                <title>Title A</title>
                
                <metadata>
                    <title>Title B</title>
                    
                    <metadata>
                        <title>Title C</title>
                    </metadata>
                </metadata>
            </metadata>
        </package>
        """
        
        @Test("Nested handlers", arguments: ChunkingStrategy.allCases)
        func nestedHandlers(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
            struct TestRoutine: Routine, ~Copyable {
                
                let ctx = context()
                
                var packageCount = 0, metadataCount = 0
                
                mutating func body() throws -> some RoutineBody {
                    try select("package") {
                        packageCount += 1
                        
                        end { packageCount += 1 }
                        
                        try select(descendant: "metadata") {
                            metadataCount += 1
                            
                            end { metadataCount += 1 }
                            
                            throw CancellationError()
                        }
                    }
                }
                
            }
            
            var routine = TestRoutine()
            
            #expect(throws: CancellationError.self) {
                try parse(xml: xml, chunking: chunkingStrategy, using: &routine)
            }
            
            #expect(routine.packageCount == 1, "child('package') called once")
            #expect(routine.metadataCount == 1, "descendant('metadata') called once")
        }
        
        @Test("Nested end handler", arguments: ChunkingStrategy.allCases)
        func nestedEndHandler(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
            struct TestRoutine: ~Copyable, Routine {
                
                let ctx = context()
                
                var packageCount = 0, metadataStartCount = 0, metadataEndCount = 0
                
                mutating func body() throws -> some RoutineBody {
                    try select("package") {
                        packageCount += 1
                        
                        end { packageCount += 1 }
                        
                        try select(descendant: "metadata") {
                            metadataStartCount += 1
                            
                            try end {
                                metadataEndCount += 1
                                
                                throw CancellationError()
                            }
                        }
                    }
                }
                
            }
            
            var routine = TestRoutine()
            
            #expect(throws: CancellationError.self) {
                try parse(xml: xml, chunking: chunkingStrategy, using: &routine)
            }
            
            #expect(routine.metadataStartCount == 3, "descendant('metadata') called expected number of times")
            #expect(routine.packageCount == 1, "child('package') called expected number of times")
            #expect(routine.metadataEndCount == 1, "descendant('metadata') end handler called expected number of times")
        }
    }

}

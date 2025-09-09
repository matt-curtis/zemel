//
//  Text.swift
//  Zemel
//
//  Created by Matt Curtis on 7/18/25.
//

import Testing
import Zemel

@Suite("Text")
struct TextTests {

    @Test("Basic", arguments: ChunkingStrategy.allCases)
    func basicTextGathering(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
        struct TestRoutine: Routine, ~Copyable {
            
            @Context var context
            
            @State var a = ""
            
            @State var b = ""
            
            @State var c = ""
            
            @State var d = ""
            
            mutating func body() throws -> some RoutineBody {
                try select(descendant: true) {
                    try select(.text) {
                        try withText {
                            a.append(String(decoding: $0, as: UTF8.self))
                        }
                    }
                    
                    try select(current.text()) {
                        b.append(try text())
                    }
                    
                    try select(.text) {
                        try withText {
                            c.append(String(decoding: $0, as: UTF8.self))
                        }
                    }
                    
                    try select(current.text()) {
                        d.append(try text())
                    }
                }
            }
            
        }
        
        var routine = TestRoutine()
        
        let xml = """
        <a>abc<b>def<c>ghi</c>jkl</b>mno</a>
        """
        
        try parse(xml: xml, chunking: chunkingStrategy, using: &routine)
        
        let expected = "abcdefghijklmno"
        
        #expect(routine.a == expected)
        #expect(routine.b == expected)
        #expect(routine.c == expected)
        #expect(routine.d == expected)
    }

}

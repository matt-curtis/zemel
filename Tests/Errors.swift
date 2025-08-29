//
//  Error Handling.swift
//  Zemel
//
//  Created by Matt Curtis on 2/18/25.
//

import Testing
import Zemel

@Suite("Errors")
struct ErrorHandling {
    
    struct NoopSelector: Routine, ~Copyable {
        
        let ctx = context()
        
        func body() -> some RoutineBody { }
        
    }
    
    @Test("Empty document", arguments: ChunkingStrategy.allCases)
    func emptyDocument(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
        #expect(throws: ZemelError.self, "Throws on empty document") {
            var selector = NoopSelector()
            
            try parse(xml: "", chunking: chunkingStrategy, using: &selector)
        }
    }
    
    @Test("Valid document", arguments: ChunkingStrategy.allCases)
    func validDocument(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
        #expect(throws: Never.self, "Doesn't throw on valid document") {
            var selector = NoopSelector()
            
            try parse(xml: "<xml></xml>", chunking: chunkingStrategy, using: &selector)
        }
    }
    
    @Test("Mismatched tags", arguments: ChunkingStrategy.allCases)
    func mismatchedTags(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
        #expect(throws: ZemelError.self, "Throws on mismatched tags") {
            var selector = NoopSelector()
            
            try parse(xml: "<a></b>", chunking: chunkingStrategy, using: &selector)
        }
    }
    
    @Test("Empty start tag", arguments: ChunkingStrategy.allCases)
    func emptyStartTag(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
        #expect(throws: ZemelError.self, "Throws on empty start tags") {
            var selector = NoopSelector()
            
            try parse(xml: "<>", chunking: chunkingStrategy, using: &selector)
        }
    }
    
    @Test("Empty closing tag", arguments: ChunkingStrategy.allCases)
    func emptyClosingTag(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
        #expect(throws: ZemelError.self, "Throws on empty closing tags") {
            var selector = NoopSelector()
            
            try parse(xml: "</>", chunking: chunkingStrategy, using: &selector)
        }
    }
    
    @Test("Rethrows user errors", arguments: ChunkingStrategy.allCases)
    func userThrownErrors(whenChunking chunkingStrategy: ChunkingStrategy) {
        enum UserError: Error { case error }
        
        struct ThrowingRoutine: Routine, ~Copyable {
            
            let ctx = context()
            
            var didThrow = 0
            
            mutating func body() throws -> some RoutineBody {
                let _ = didThrow += 1
                
                throw UserError.error
            }
            
        }
        
        var routine = ThrowingRoutine()
        
        #expect(throws: UserError.error, "Rethrows user errors") {
            try parse(xml: "<xml></xml>", chunking: chunkingStrategy, using: &routine)
        }
        
        #expect(routine.didThrow == 1)
    }
    
    @Test("Rethrows user selection errors", arguments: ChunkingStrategy.allCases)
    func userSelectorThrownErrors(whenChunking chunkingStrategy: ChunkingStrategy) {
        enum UserError: Error { case child, descendant, chainChild, chainDescendant }
        
        struct ThrowingRoutine: Routine, ~Copyable {
            
            let ctx = context()
            
            var bodyCallCount = 0
            
            var error: UserError
            
            mutating func throwing(_ expectedError: UserError) throws -> Bool {
                if expectedError == error {
                    throw error
                }
                
                return false
            }
            
            mutating func body() throws -> some RoutineBody {
                let _ = bodyCallCount += 1
                
                try select(throwing(.child)) { }
                try select(descendant: throwing(.descendant)) { }
                try select(current.child(throwing(.chainChild))) { }
                try select(current.descendant(throwing(.chainDescendant))) { }
            }
            
        }
        
        func test(error: UserError, sourceLocation: SourceLocation = #_sourceLocation) {
            var routine = ThrowingRoutine(error: error)
            
            #expect(throws: error, "\(error) was thrown") {
                try parse(xml: "<xml></xml>", chunking: chunkingStrategy, using: &routine)
            }
            
            #expect(routine.bodyCallCount == 1, "body called once")
        }
        
        test(error: .child)
        test(error: .descendant)
        test(error: .chainChild)
        test(error: .chainDescendant)
    }
    
}

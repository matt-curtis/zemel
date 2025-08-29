//
//  ErrorHandling.swift
//  Zemel
//
//  Created by Matt Curtis on 6/24/25.
//

import Testing
import Zemel

@Suite("State")
struct StateManagement {
    
    struct TestRoutine: Routine, ~Copyable {
        
        let ctx = context()
        
        enum SelectorKind: CaseIterable {
            
            case childByName, descendantByName
            case childByCondition, descendantByCondition
            case containerSelectorChain
            
        }
        
        class DeinitReportingObject {
            
            let selectorKind: SelectorKind
            
            let selectorKindConfirmingCollection: SelectorKindConfirmingCollection
            
            init(selectorKind: SelectorKind, selectorKindConfirmingCollection: SelectorKindConfirmingCollection) {
                self.selectorKind = selectorKind
                self.selectorKindConfirmingCollection = selectorKindConfirmingCollection
            }
            
            deinit {
                selectorKindConfirmingCollection.confirm(selectorKind)
            }
            
        }
        
        class SelectorKindConfirmingCollection {
            
            private var confirmedKinds: Set<SelectorKind> = []
            
            var confirm: Confirmation?
            
            func reset() {
                confirmedKinds = []
            }
            
            func confirm(_ kind: SelectorKind) {
                confirmedKinds.insert(kind)
                
                if confirmedKinds == Set(SelectorKind.allCases) {
                    confirm?()
                }
            }
            
        }
        
        let selectorKindConfirmingCollection = SelectorKindConfirmingCollection()
        
        init(confirm: Confirmation?) {
            selectorKindConfirmingCollection.confirm = confirm
        }
        
        func deinitReportingObject(for selectorKind: SelectorKind) -> DeinitReportingObject {
            DeinitReportingObject(
                selectorKind: selectorKind,
                selectorKindConfirmingCollection: selectorKindConfirmingCollection
            )
        }
        
        func body() throws -> some RoutineBody {
            select("xml") {
                let _ = $0(deinitReportingObject(for: .childByName))
            }
            
            select(true) {
                let _ = $0(deinitReportingObject(for: .childByCondition))
            }
            
            select(descendant: "xml") {
                let _ = $0(deinitReportingObject(for: .descendantByName))
            }
            
            select(descendant: true) {
                let _ = $0(deinitReportingObject(for: .descendantByCondition))
            }
            
            select(current.child("xml")) {
                let _ = $0(deinitReportingObject(for: .containerSelectorChain))
            }
        }
        
    }
    
    @Test("Resets when routine is deinitialized", arguments: ChunkingStrategy.allCases)
    func resetsWhenRoutineIsDeinitialized(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
        _ = try await confirmation("Data released when routine is deinitialized") {
            confirm in
            
            var routine = TestRoutine(confirm: confirm)
            
            try parse(xml: "<xml></xml>", chunking: chunkingStrategy, using: &routine)
        }
    }
    
    @Test("Resets when routine is reset", arguments: ChunkingStrategy.allCases)
    func resetsWhenRoutineIsReset(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
        var routine = TestRoutine(confirm: nil)
        
        _ = try await confirmation("Data released when routine is reset") {
            confirm in
            
            routine.selectorKindConfirmingCollection.confirm = confirm
            
            try parse(xml: "<xml></xml>", chunking: chunkingStrategy, using: &routine)
            
            routine.ctx.reset()
        }
        
        routine.selectorKindConfirmingCollection.reset()
        
        _ = try await confirmation("Can successfully create and release new data successfully after reset") {
            confirm in
            
            routine.selectorKindConfirmingCollection.confirm = confirm
            
            try parse(xml: "<xml></xml>", chunking: chunkingStrategy, using: &routine)
        }
    }
    
}

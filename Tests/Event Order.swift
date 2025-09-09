//
//  Event Handling.swift
//  Zemel
//
//  Created by Matt Curtis on 2/17/25.
//

import Testing
@testable import Zemel

@Suite("Event Order")
struct EventOrder {
    
    enum Event: Equatable {
        
        case elementStart(Name)
        case elementEnd(Name)
        case text(String)
        
    }
    
    @Test("Event order", arguments: ChunkingStrategy.allCases)
    func eventOrder(whenChunking chunkingStrategy: ChunkingStrategy) throws {
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
        
        let expectedEvents: [ Event ] = [
            .elementStart("package"),
                .elementStart("metadata"),
                    .elementStart("title"),
                        .text("Title A"),
                    .elementEnd("title"),
            
                    .elementStart("metadata"),
                        .elementStart("title"),
                            .text("Title B"),
                        .elementEnd("title"),
            
                        .elementStart("metadata"),
                            .elementStart("title"),
                                .text("Title C"),
                            .elementEnd("title"),
                        .elementEnd("metadata"),
                    .elementEnd("metadata"),
                .elementEnd("metadata"),
            .elementEnd("package")
        ]
        
        struct TestRoutine: Routine, ~Copyable {
            
            @Context var context
            
            @State var events: [ Event ] = []
            
            func record(_ event: Event) {
                events.append(event)
            }
            
            func recordText() throws {
                record(.text(try text()))
            }
            
            @RoutineBodyBuilder func recordStartAndEnd(state: borrowing UnintializedSelectorState<Name>) throws -> some RoutineBody {
                let elementName = try state(try name())
                
                record(.elementStart(elementName.value))
                
                end {
                    record(.elementEnd(elementName.value))
                }
            }
            
            func body() throws -> some RoutineBody {
                try select("package") {
                    try recordStartAndEnd(state: $0)
                    
                    try select(descendant: "metadata") {
                        try recordStartAndEnd(state: $0)
                        
                        try select("title") {
                            try select(.text) {
                                try recordText()
                            }
                            
                            try recordStartAndEnd(state: $0)
                        }
                    }
                }
            }
            
        }
        
        var routine = TestRoutine()
        
        try parse(xml: xml, chunking: chunkingStrategy, using: &routine)
        
        #expect(routine.events == expectedEvents, "events emitted in expected order")
    }
    
}

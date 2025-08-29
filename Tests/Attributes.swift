//
//  Attributes.swift
//  Zemel
//
//  Created by Matt Curtis on 7/7/25.
//

import Testing
import Zemel

@Suite("Attribute iteration")
struct AttributeIteration {

    @Test("Iteration", arguments: ChunkingStrategy.allCases)
    func iteration(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
        struct TestRoutine: Routine, ~Copyable {
            
            let ctx = context()
            
            struct Attribute: Equatable, CustomDebugStringConvertible {
                
                let name: Name
                
                let value: String
                
                var debugDescription: String {
                    """
                    Attribute(name: \(name.debugDescription), value: "\(value)")
                    """
                }
                
            }
            
            func attributes() throws -> [ Attribute ] {
                var attributes: [ Attribute ] = []
                
                try withAttributes {
                    repeat {
                        attributes.append(Attribute(name: $0.name(), value: $0.value()))
                    }
                    while $0.next()
                }
                
                return attributes
            }
            
            mutating func body() throws -> some RoutineBody {
                try select("a") {
                    try handle {
                        let attributes = try attributes()
                        
                        #expect(
                             attributes == [
                                Attribute(name: Name("aa"), value: "aavalue"),
                                Attribute(name: Name("ab"), value: "abvalue"),
                                Attribute(name: Name(ns: "ns1.com", localName: "ac"), value: "acvalue")
                            ]
                        )
                    }
                    
                    try select("b") {
                        try handle {
                            let attributes = try attributes()
                            
                            #expect(attributes == [])
                        }
                        
                        try select("c") {
                            try handle {
                                let attributes = try attributes()
                                
                                #expect(
                                    attributes == [
                                        Attribute(name: Name("ca"), value: "cavalue"),
                                        Attribute(name: Name("cb"), value: "cbvalue"),
                                        Attribute(name: Name(ns: "ns2.com", localName: "cc"), value: "ccvalue")
                                    ]
                                )
                            }
                        }
                    }
                }
            }
            
        }
        
        var routine = TestRoutine()
        
        let xml = """
        <a xmlns:ns1="ns1.com" aa="aavalue" ab="abvalue" ns1:ac="acvalue">
            <b xmlns:ns2="ns2.com">
                <c ca="cavalue" cb="cbvalue" ns2:cc="ccvalue"></c>
            </b>
        </a>
        """
        
        try parse(xml: xml, chunking: chunkingStrategy, using: &routine)
    }

}

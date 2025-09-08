//
//  Namespace Handling.swift
//  Zemel
//
//  Created by Matt Curtis on 2/18/25.
//

import Testing
import Zemel

@Suite("Namespaces")
struct NamespaceHandling {
    
    @Suite("Attributes")
    struct AttributeNamespaceHandling {
        
        @Test("Unprefixed have no namespace", arguments: ChunkingStrategy.allCases)
        func unprefixedHaveNoNamespaces(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
            enum Constants {
                
                nonisolated(unsafe) static let ns: Namespace = "http://zemel.com"
                
            }
            
            let xml = """
            <root testAttribute="some value" xmlns="\(Constants.ns.uri.asString())">
                <child testAttribute="some value" />
            </root>
            """
            
            struct TestRoutine: Routine, ~Copyable {
                
                @Context var context
                
                var elementCount = 0
                
                let ns = Constants.ns
                
                mutating func body() throws -> some RoutineBody {
                    try select(descendant: true) {
                        var attributeCount = 0
                        
                        try handle {
                            let value = try attribute("testAttribute")
                            
                            #expect(value == "some value", "has expected value")
                        }
                        
                        try handle {
                            try withAttributes {
                                let name = $0.name()
                                
                                #expect(name.ns == nil, "has no namespace")
                                #expect(name.has(ns: ns) == false, "has no namespace")
                                
                                #expect(name.has(localName: "testAttribute") == true, "has expected local name")
                                #expect(name.localName.asString() == "testAttribute", "has expected local name")
                                
                                #expect(name.has(ns: ns, andLocalName: "wrong") == false, "fails wrong name test")
                                #expect(name != Name(ns: ns, localName: "testAttribute"), "fails wrong name test")
                                
                                #expect(name == Name(ns: nil, localName: "testAttribute"), "passes name test")
                                
                                #expect($0.has(value: "some value") == true, "has expected value")
                                #expect($0.value() == "some value", "has expected value")
                                
                                attributeCount += 1
                            }
                        }
                        
                        #expect(attributeCount == 1, "only one attribute")
                        
                        elementCount += 1
                    }
                }
                
            }
            
            var routine = TestRoutine()
            
            try parse(xml: xml, chunking: chunkingStrategy, using: &routine)
            
            #expect(routine.elementCount == 2, "two elements")
        }
        
        @Test("Prefixed attributes have namespaces", arguments: ChunkingStrategy.allCases)
        func prefixedHaveNamespaces(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
            enum Constants {
                
                nonisolated(unsafe) static let ns2: Namespace = "http://ns2.com"
                
            }
            
            let xml = """
            <root ns2:testAttribute="some value" xmlns="http://zemel.com" xmlns:ns2="\(Constants.ns2.uri.asString())">
                <child ns2:testAttribute="some value" />
            </root>
            """
            
            struct TestRoutine: Routine, ~Copyable {
                
                @Context var context
                
                var elementCount = 0
                
                mutating func body() throws -> some RoutineBody {
                    let ns2 = Constants.ns2
                    
                    try select(descendant: true) {
                        var attributeCount = 0
                        
                        try handle {
                            let value = try attribute(Constants.ns2["testAttribute"])
                            
                            #expect(value == "some value", "has expected value")
                        }
                        
                        try handle {
                            try withAttributes {
                                let name = $0.name()
                                
                                #expect(name.has(ns: ns2) == true, "has namespace")
                                
                                #expect(name.has(localName: "testAttribute") == true, "has expected local name")
                                
                                #expect(name.has(ns: ns2, andLocalName: "wrong") == false, "fails wrong name test")
                                #expect(name != Name(ns: "nope", localName: "testAttribute"), "fails wrong name test")
                                #expect(name != Name(ns: nil, localName: "testAttribute"), "fails no-ns test")
                                
                                #expect($0.has(value: "some value") == true, "has expected value")
                                #expect($0.value() == "some value", "has expected value")
                                
                                attributeCount += 1
                            }
                            
                            #expect(attributeCount == 1, "only one attribute")
                        }
                        
                        elementCount += 1
                    }
                }
                
            }
            
            var routine = TestRoutine()
            
            try parse(xml: xml, chunking: chunkingStrategy, using: &routine)
            
            #expect(routine.elementCount == 2, "two elements")
        }
        
    }
    
    @Suite("Elements")
    struct ElementsNamespaceHandling {
        
        @Test("Basic namespaces", arguments: ChunkingStrategy.allCases)
        func basicNamespaces(whenChunking chunkingStrategy: ChunkingStrategy) async throws {
            enum Constants {
                
                nonisolated(unsafe) static let rootNS: Namespace = "http://root.ns"
                nonisolated(unsafe) static let nsA: Namespace = "http://a.ns"
                nonisolated(unsafe) static let nsB: Namespace = "http://b.ns"
                
                static let xml = """
                <doc xmlns="\(rootNS.uri.asString())" xmlns:b="\(nsB.uri.asString())">
                    <node>
                        <node></node>
                    </node>
                
                    <node xmlns="\(nsA.uri.asString())">
                        <node></node>
                    </node>
                    
                    <b:node>
                        <b:node />
                    </b:node>
                </doc>
                """
                
            }
            
            struct TestRoutine: ~Copyable, Routine {
                
                @Context var context
                
                @CountBasedExpectation(expecting: "doc", times: 1) var docExpectation
                
                @CountBasedExpectation(expecting: "node", times: 1) var nodeExpectation
                
                @CountBasedExpectation(expecting: "node > node", times: 1) var nodeChildExpectation
                
                @CountBasedExpectation(expecting: "nsA['node']", times: 1) var nsAChildExpectation
                @CountBasedExpectation(expecting: "nsA['node'] > nsA['node']", times: 1) var nsAChild2Expectation
                
                @CountBasedExpectation(expecting: "nsB['node']", times: 1) var nsBChildExpectation
                @CountBasedExpectation(expecting: "nsB['node'] > nsB['node']", times: 1) var nsBChild2Expectation
                
                mutating func body() throws -> some RoutineBody {
                    select(Name(ns: "doesNotExist", localName: "doc")) {
                        Issue.record("Non-existent selector matched")
                    }
                    
                    select(Constants.rootNS["doc"]) {
                        docExpectation.record()
                        
                        select(Name(ns: "doesNotExist", localName: "node")) {
                            Issue.record("Non-existent selector matched")
                        }
                        
                        select(Constants.rootNS["node"]) {
                            nodeExpectation.record()
                            
                            select(Constants.rootNS["node"]) {
                                nodeChildExpectation.record()
                            }
                        }
                        
                        select(Constants.nsA["node"]) {
                            nsAChildExpectation.record()
                            
                            select(Constants.nsA["node"]) {
                                nsAChild2Expectation.record()
                            }
                        }
                        
                        select(Constants.nsB["node"]) {
                            nsBChildExpectation.record()
                            
                            select(Constants.nsB["node"]) {
                                nsBChild2Expectation.record()
                            }
                        }
                    }
                }
                
            }
            
            var routine = TestRoutine()
            
            try parse(xml: Constants.xml, chunking: chunkingStrategy, using: &routine)
        }
        
    }
    
}

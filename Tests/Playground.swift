//
//  Test.swift
//  Zemel
//
//  Created by Matt Curtis on 3/20/25.
//

import Testing
import Zemel

@Suite("Playground", .disabled())
struct Playground {
    
    //    @Test("Profile bare bones")
    //    func profileBarebones() async throws {
    //        struct TestSelector: Routine, ~Copyable {
    //
    //            @Context var context
    //
    //            func body() -> some RoutineBody {
    //
    //            }
    //
    //        }
    //
    //        var selector = TestSelector()
    //        var zemel = Zemel()
    //
    //        try zemel.using(&selector) {
    //            parse in
    //
    //            try profile("Zemel.body()") {
    //                for _ in 0..<50_000 {
    //                    try parse(final: false, chunk: "<root>test")
    //                }
    //            }
    //        }
    //    }
    
    @Test("Profile basic selection")
    func profileBasicSelection() throws {
        struct TestSelector: Routine, ~Copyable {
            
            @Context var context
            
            func body() -> some RoutineBody {
                select("root") {
                    let _ = $0("hi")
                    
                    select("child") {
                        end {
                            
                        }
                    }
                }
            }
            
        }
        
        var selector = TestSelector()
        var zemel = Zemel()
        
        try zemel.using(&selector) {
            parse in
            
            try profile("Zemel.body()") {
                for _ in 0..<500_000 {
                    try parse(final: false, chunk: "<root>test")
                }
            }
        }
    }
    
//    @Test("testRecursivelyNestedXML")
//    func testRecursivelyNestedXML() {
//        func generateRecursiveMetadata(depth: Int) -> String {
//            guard depth > 0 else { return "" }
//            
//            return """
//            <metadata>
//                <title>Some title</title>
//                <creator>Some creator</creator>
//                <creator>Some other creator</creator>
//                <description>Some description</description>
//                
//                \(generateRecursiveMetadata(depth: depth - 1))
//            </metadata>
//            """
//        }
//        
//        let xml = """
//        <?xml version='1.0' encoding='UTF-8'?>
//        <package>
//            \(generateRecursiveMetadata(depth: 20))
//        </package>
//        """
//        
//        struct TestRoutine: ~Copyable, Routine {
//            
//            @Context var context
//            
//            var description: String?
//            
//            var titles: [ String ] = []
//            
//            var authors: [ String ] = []
//            
//            mutating func body() throws -> some RoutineBody {
//                try select("package") {
//                    try select(descendant: "metadata") {
//                        try select("title") {
//                            try select(.text) { titles.append(try text()) }
//                        }
//                        
//                        try select("creator") {
//                            try select(.text) { authors.append(try text()) }
//                        }
//                        
//                        try select("description") {
//                            try select(.text) { description = try text() }
//                        }
//                    }
//                }
//            }
//            
//        }
//        
//        var zemel = Zemel()
//        var routine = TestRoutine()
//        
//        profile("recursive") {
//            for _ in 0..<5_000 {
//                zemel.using(&routine) {
//                    parse in
//                    
//                    try! parse(final: true, chunk: xml)
//                }
//            }
//        }
//    }
    
//    @Test("Play")
//    func play() async throws {
//        struct TestRoutine: Routine, ~Copyable {
//            
//            @Context var context
//            
//            func body() -> some RoutineBody {
//                let _ = print("\nroutine start")
//                
//                let a = state(0)
//                
//                let _ = { print("a", a.value); a.value += 1 }()
//                
//                if a.value == 1 || a.value == 3 {
//                    let b = state(0)
//                    
//                    let _ = { print("b", b.value); b.value += 1 }()
//                }
//                
//                let c = state(90)
//                
//                let _ = { print("c", c.value); c.value += 1 }()
//            }
//            
//        }
//        
//        var routine = TestRoutine()
//        var zemel = Zemel()
//        
//        try zemel.using(&routine) {
//            parse in
//            
//            try parse(final: false, chunk: "<root>test</root>")
//        }
//    }
//    
    @Test("Play 2")
    func play2() async throws {
        struct TestSelector: Routine, ~Copyable {
            
            @Context var context
            
            class Hmm {
                
                init() {
                    print("hmm created")
                }
                
                deinit {
                    print("hmm destroyed")
                }
                
            }
            
            func body() -> some RoutineBody {
//                select("root") {
//                    let state = $0(Hmm())
//                    
//                    select("child") {
//                        print("test")
//                        
//                        end {
//                            print("child closing")
//                        }
//                    }
//                    
//                    end {
//                        print("root closing")
//                    }
//                }
            }
            
        }
        
        var selector = TestSelector()
        var zemel = Zemel()
        
        try zemel.using(&selector) {
            parse in
            
            try parse(final: false, chunk: "<root>test")
            try parse(final: false, chunk: "<child>test</child></root>")
        }
    }
//    
//    @Test("what")
//    func test() throws {
//        struct TestSelector: Routine, ~Copyable {
//            
//            @Context var context
//            
//            var text = ""
//            
//            mutating func body() throws -> Body {
//                try select(current.a.b.text()) {
//                    text += try text()
//                }
//                
//                select("a") {
//                    let foo = state("...")
//                    
//                    print("hi")
//                    
//                    end {
//                        print("bye", foo.value)
//                    }
//                    
//                    select(current.b) {
//                        print("b!")
//                    }
//                }
//            }
//            
//        }
//        
//        var selector = TestSelector()
//        var zemel = Zemel()
//        
//        try zemel.using(&selector) {
//            parse in
//            
//            try parse(final: true, chunk: "<a><b>test!!!</b></a>")
//        }
//    }
    
}

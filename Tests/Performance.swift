import XCTest
import Zemel

class PerformanceTests: XCTestCase {
    
    func testRecursivelyNestedXML() {
        func generateRecursiveMetadata(depth: Int) -> String {
            guard depth > 0 else { return "" }
            
            return """
            <metadata>
                <title>Some title</title>
                <creator>Some creator</creator>
                <creator>Some other creator</creator>
                <description>Some description</description>
                
                \(generateRecursiveMetadata(depth: depth - 1))
            </metadata>
            """
        }
        
        let xml = """
        <?xml version='1.0' encoding='UTF-8'?>
        <package>
            \(generateRecursiveMetadata(depth: 20))
        </package>
        """
        
        struct TestRoutine: ~Copyable, Routine {
            
            @Context var context
            
            @State var description: String?
            
            @State var titles: [ String ] = []
            
            @State var authors: [ String ] = []
            
            func body() throws -> some RoutineBody {
                try select("package") {
                    try select(descendant: "metadata") {
                        try select("title") {
                            let title = $0("")
                            
                            try select(.text) { title.value += try text() }
                            end { titles.append(title.value) }
                        }
                        
                        try select("creator") {
                            let author = $0("")
                            
                            try select(.text) { author.value += try text() }
                            end { authors.append(author.value) }
                        }
                        
                        try select("description") {
                            try select(.text) { description = try text() }
                        }
                    }
                }
            }
            
        }
        
        var zemel = Zemel()
        var routine = TestRoutine()
        
        measure {
            for _ in 0..<500 {
                zemel.using(&routine) {
                    parse in
                    
                    try! parse(final: true, chunk: xml)
                }
            }
        }
    }

}

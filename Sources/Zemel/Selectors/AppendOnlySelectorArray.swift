//
//  AppendOnlySelectorArray.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

struct AppendOnlySelectorArray: Deinitializable {
    
    private struct Element {
        
        let type: SelectorKind
        
        let pointer: UnsafeMutableRawPointer
        
        func deinitialize() {
            type.deinitialize(pointer)
        }
        
    }
    
    private var array: AppendOnlyArray<Element>
    
    var hasNext: Bool { array.hasNext }
    
    init(initialCapacity: Int) {
        self.array = .init(initialCapacity: initialCapacity)
    }
    
    func deinitialize() {
        array.forEach { $0.deinitialize() }
        array.deinitialize()
    }
    
    mutating func resetCursor() {
        array.resetCursor()
    }
    
    mutating func append(pointer: UnsafeMutableRawPointer, type: SelectorKind) {
        array.append(Element(type: type, pointer: pointer))
    }
    
    mutating func next() -> (pointer: UnsafeMutableRawPointer, type: SelectorKind) {
        let next = array.next()
        
        return (next.pointer, next.type)
    }
    
}

//
//  AppendOnlyArray.swift
//  Zemel
//
//  Created by Matt Curtis on 4/28/25.
//

/// Append-only, forward-iterable array.

struct AppendOnlyArray<Element>: Deinitializable {
    
    private var buffer: GrowableBuffer<Element>
    
    private var cursor = 0
    
    private var count = 0
    
    var hasNext: Bool { cursor < count }
    
    init(initialCapacity: Int) {
        self.buffer = .init(initialCapacity: initialCapacity)
    }
    
    func deinitialize() {
        buffer.base.deinitialize(count: count)
        buffer.base.deallocate()
    }
    
    func forEach(_ body: (Element) -> Void) {
        var element = buffer.base
        
        for _ in 0..<count {
            body(element.pointee)
            
            element += 1
        }
    }
    
    mutating func resetCursor() {
        cursor = 0
    }
    
    mutating func reset() {
        buffer.base.deinitialize(count: count)
        
        cursor = 0
        count = 0
    }
    
    mutating func append(_ newElement: Element) {
        precondition(cursor == count, "Appending is only allowed when cursor is at end")
        
        if count == buffer.capacity {
            buffer.grow(moving: count)
        }
        
        (buffer.base + cursor).initialize(to: newElement)
        
        cursor += 1
        count += 1
    }
    
    mutating func next() -> Element {
        precondition(cursor < count, "Out of bounds access; no more elements remain")
        
        defer { cursor += 1 }
        
        return buffer.base[cursor]
    }
    
}

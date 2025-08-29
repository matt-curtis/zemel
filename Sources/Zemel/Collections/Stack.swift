//
//  Stack.swift
//  Zemel
//
//  Created by Matt Curtis on 5/17/25.
//

/// A last-in, first-out stack.

struct Stack<Element>: Deinitializable {
    
    private var buffer: GrowableBuffer<Element>
    
    private var count = 0
    
    var isEmpty: Bool { count == 0 }
    
    var last: UnsafeMutablePointer<Element>? {
        if isEmpty { return nil }
        
        return buffer.base + (count - 1)
    }
    
    init(initialCapacity: Int) {
        self.buffer = .init(initialCapacity: initialCapacity)
    }
    
    func deinitialize() {
        buffer.base.deinitialize(count: count)
        buffer.base.deallocate()
    }
    
    func forEach(_ body: (borrowing Element) -> Void) {
        var element = buffer.base
        
        for _ in 0..<count {
            body(element.pointee)
            
            element += 1
        }
    }
    
    mutating func push(_ newElement: Element) {
        if count == buffer.capacity {
            buffer.grow(moving: count)
        }
        
        (buffer.base + count).initialize(to: newElement)
        
        count += 1
    }
    
    mutating func pop(body: (inout Element) -> Void = { _ in }) {
        precondition(count > 0, "Cannot pop empty stack")
        
        let pointerToLast = buffer.base + (count - 1)
        
        body(&pointerToLast.pointee)
        
        pointerToLast.deinitialize(count: 1)
        
        count -= 1
    }
    
}

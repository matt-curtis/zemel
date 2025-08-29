//
//  GrowableBuffer.swift
//  Zemel
//
//  Created by Matt Curtis on 5/4/25.
//

/// Manages a buffer using an exponential growth strategy.
/// When buffer growth is requested, a new buffer is allocated double the capacity of the old.
/// User is responsible for deallocating the buffer when it's no longer needed.

struct GrowableBuffer<Element> {
    
    private(set) var base: UnsafeMutablePointer<Element>
    
    private(set) var capacity: Int
    
    init(initialCapacity: Int) {
        self.base = .allocate(capacity: initialCapacity)
        self.capacity = initialCapacity
    }
    
    /// Allocates a new buffer, then calls `move` with the old and new buffers. The old buffer is deallocated after.
    
    mutating func grow<R>(move: (UnsafeMutablePointer<Element>, UnsafeMutablePointer<Element>) -> R) -> R {
        let newCapacity = max(capacity, 1) * 2
        let newBuffer = UnsafeMutablePointer<Element>.allocate(capacity: newCapacity)
        
        defer {
            base.deallocate()
            base = newBuffer
            
            capacity = newCapacity
        }
        
        return move(base, newBuffer)
    }
    
    ///  Grows the buffer, moving `count` elements over.
    
    mutating func grow(moving count: Int) {
        grow {
            old, new in
            
            new.moveInitialize(from: old, count: count)
        }
    }
    
}

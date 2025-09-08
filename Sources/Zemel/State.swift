//
//  State.swift
//  Zemel
//
//  Created by Matt Curtis on 9/8/25.
//

/// A property wrapper that can read and write to a value held by a `Routine`.

@propertyWrapper
public struct State<Value>: ~Copyable {
    
    let pointer: UnsafeMutableRawPointer
    
    @usableFromInline
    var typedPointer: UnsafeMutablePointer<Value> {
        pointer.assumingMemoryBound(to: Value.self)
    }
    
    public var wrappedValue: Value {
        get { typedPointer.pointee }
        nonmutating _modify { yield &typedPointer.pointee }
        nonmutating set { typedPointer.pointee = newValue }
    }
    
    @usableFromInline
    init(createPointer: () -> UnsafeMutableRawPointer) {
        self.pointer = createPointer()
    }
    
    @inlinable
    public init(wrappedValue: Value) {
        self.init {
            let pointer = UnsafeMutablePointer<Value>.allocate(capacity: 1)
            
            pointer.initialize(to: wrappedValue)
            
            return UnsafeMutableRawPointer(pointer)
        }
    }
    
    @usableFromInline
    func deinitialize(using destroyPointer: (UnsafeMutableRawPointer) -> Void) {
        destroyPointer(pointer)
    }
    
    @inlinable
    deinit {
        deinitialize {
            rawPointer in
            
            let pointer = rawPointer.assumingMemoryBound(to: Value.self)
            
            pointer.deinitialize(count: 1)
            pointer.deallocate()
        }
    }
    
}

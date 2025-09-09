//
//  SelectorState.swift
//  Zemel
//
//  Created by Matt Curtis on 3/8/25.
//

import Foundation

/// A callable function that returns `SelectorState` after ensuring state has been safely initialized.

public struct UnintializedSelectorState<Value>: ~Copyable {
    
    //  MARK: - Properties
    
    @usableFromInline
    let ctx: UnsafeRoutineContext
    
    @usableFromInline
    let nodeIndex: Int
    
    private let referenceCountToken: ReferenceCountToken
    
    
    //  MARK: - Init
    
    init(ctx: UnsafeRoutineContext, nodeIndex: Int, referenceCountToken: consuming ReferenceCountToken) {
        self.ctx = ctx
        self.nodeIndex = nodeIndex
        self.referenceCountToken = referenceCountToken
    }
    
    
    //  MARK: - Methods
    
    @inlinable
    func initializePointer(to initialValue: Value) -> UnsafeMutableRawPointer {
        let newPointer = UnsafeMutablePointer<Value>.allocate(capacity: 1)
        
        newPointer.initialize(to: initialValue)
        
        return UnsafeMutableRawPointer(newPointer)
    }
    
    @usableFromInline
    func stateReference<T>(over pointer: UnsafeMutablePointer<T>) -> SelectorState<T> {
        SelectorState(pointer: pointer, referenceCountToken: referenceCountToken.newToken())
    }
    
    /// Returns mutable state. If uninitialized, the value returned by `initialValue()` is used to initialize it first.
    
    @inlinable
    public func callAsFunction(_ initialValue: @autoclosure () throws -> Value) rethrows -> SelectorState<Value> {
        let pointer = try ctx.checkedPointerToUserState(
            at: nodeIndex,
            initializer: { initializePointer(to: try initialValue()) },
            type: UserStateType(for: Value.self)
        )
        
        return stateReference(over: pointer.assumingMemoryBound(to: Value.self))
    }
    
    /// Returns mutable state. If uninitialized, the value returned by `initialValue()` is used to initialize it first.
    /// Doesn't check that the passed state type matches the stored state type, which can improve performance in some cases.
    /// - Warning: If you need this, you'll know. If you don't know... you don't need it.
    
    @inlinable
    public func callAsFunction(unchecked initialValue: @autoclosure () throws -> Value) rethrows -> SelectorState<Value> {
        let pointer = try ctx.uncheckedPointerToUserState(
            at: nodeIndex,
            initializer: { initializePointer(to: try initialValue()) }
        )
        
        return stateReference(over: pointer.assumingMemoryBound(to: Value.self))
    }
    
}

/// Provides a mutable reference to a value associated with a selector.
/// `SelectorState` references must not escape their scope and be stored or returned; doing so will result in an assertion.

@dynamicMemberLookup
public struct SelectorState<Value>: ~Copyable {
    
    @usableFromInline
    let pointer: UnsafeMutablePointer<Value>
    
    let referenceCountToken: ReferenceCountToken
    
    /// The wrapped state value.
    
    @inlinable
    public var value: Value {
        nonmutating get { pointer.pointee }
        nonmutating _modify { yield &pointer.pointee }
        nonmutating set { pointer.pointee = newValue }
    }
    
    init(pointer: UnsafeMutablePointer<Value>, referenceCountToken: consuming ReferenceCountToken) {
        self.pointer = pointer
        self.referenceCountToken = referenceCountToken
    }
    
    @inlinable
    public subscript<T>(dynamicMember keyPath: WritableKeyPath<Value, T>) -> T {
        nonmutating get { pointer.pointee[keyPath: keyPath] }
        nonmutating _modify { yield &pointer.pointee[keyPath: keyPath] }
        nonmutating set { pointer.pointee[keyPath: keyPath] = newValue }
    }
    
}

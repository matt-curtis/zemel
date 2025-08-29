//
//  NodeStateReferences.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

/// Tracks references and deallocation logic for a node's state.

struct NodeStateReferences {
    
    //  MARK: - Properties
    
    private var selectorPointerBox: SelectorPointerBox?
    
    private var userStateSlots: Stack<UnsafeMutableRawPointer?>
    
    private var userStateType: UserStateType?
    
    
    //  MARK: - Init
    
    init() {
        self.userStateSlots = Stack(initialCapacity: 1)
    }
    
    
    //  MARK: - Deinitialization
    
    mutating func deinitialize(usingUserStateDeinitializer userStateDeinitializer: (UnsafeMutableRawPointer) -> Void) {
        selectorPointerBox?.deinitializeAndDeallocateBoxedPointer()
        
        userStateSlots.forEach {
            if let pointer = $0 {
                userStateDeinitializer(pointer)
            }
        }
        
        userStateSlots.deinitialize()
    }
    
    
    //  MARK: - State pointers
    
    //  MARK: Selectors
    
    mutating func pointerToSelector<S: Selector>(initialValue initial: @autoclosure () -> S) -> UnsafeMutablePointer<S> {
        if let selectorPointerBox {
            return selectorPointerBox.unbox(expecting: S.self)
        } else {
            let pointer = UnsafeMutablePointer<S>.allocate(capacity: 1)
            
            pointer.initialize(to: initial())
            
            selectorPointerBox = .init(boxing: pointer)
            
            return pointer
        }
    }
    
    
    //  MARK: User state
    
    mutating func pushEmptyUserStateSlot() {
        userStateSlots.push(nil)
    }
    
    mutating func uncheckedPointerToUserState(initializer: () throws -> UnsafeMutableRawPointer) rethrows -> UnsafeMutableRawPointer {
        guard let slot = userStateSlots.last else {
            preconditionFailure("Unexpectedly encountered empty user state slot")
        }
        
        if let pointer = slot.pointee {
            return pointer
        }
        
        let pointer = try initializer()
        
        slot.pointee = pointer
        
        return pointer
    }
    
    mutating func checkedPointerToUserState(initializer: () throws -> UnsafeMutableRawPointer, type: UserStateType) rethrows -> UnsafeMutableRawPointer {
        if let storedUserStateType = userStateType {
            storedUserStateType.check(against: type)
        } else {
            userStateType = type
        }
        
        return try uncheckedPointerToUserState(initializer: initializer)
    }
    
    mutating func popUserStateSlot(using deinitializer: (UnsafeMutableRawPointer) -> Void) {
        userStateSlots.pop {
            guard let pointer = $0 else { return }
            
            deinitializer(pointer)
            
            pointer.deallocate()
        }
    }
    
}

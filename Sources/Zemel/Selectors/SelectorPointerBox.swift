//
//  SelectorPointerBox.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

struct SelectorPointerBox {
    
    private let kind: SelectorKind
    
    private let raw: UnsafeMutableRawPointer
    
    init<S: Selector>(boxing pointer: UnsafeMutablePointer<S>) {
        self.raw = UnsafeMutableRawPointer(pointer)
        self.kind = S.kind
    }
    
    func unbox<Expected: Selector>(expecting: Expected.Type) -> UnsafeMutablePointer<Expected> {
        precondition(kind == Expected.kind, "Boxed selector doesn't match expected type")
        
        return raw.assumingMemoryBound(to: Expected.self)
    }
    
    func deinitializeAndDeallocateBoxedPointer() {
        kind.deinitialize(raw)
        
        raw.deallocate()
    }
    
}

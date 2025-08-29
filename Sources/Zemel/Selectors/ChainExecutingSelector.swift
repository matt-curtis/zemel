//
//  ChainExecutingSelector.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

struct ChainExecutingSelector: Selector {
    
    static let kind = SelectorKind(Self.self)
    
    private var array = AppendOnlySelectorArray(initialCapacity: 4)
    
    private var chainLength = 0
    
    func deinitialize() {
        array.deinitialize()
    }
    
    mutating func select(using chain: () throws -> SelectorChainResult, in context: UnsafeRoutineContext) rethrows -> SelectionEvent {
        array.resetCursor()
        
        let result = try context.with(selectorChainState: &array, body: chain)
        
        if chainLength == 0 {
            chainLength = result.chainLength
        } else {
            precondition(
                result.chainLength == chainLength,
                "Selector chain mismatch. Selector chains must be constant."
            )
        }
        
        return result.selectionEvent
    }
    
}

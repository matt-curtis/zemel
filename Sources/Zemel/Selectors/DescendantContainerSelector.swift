//
//  DescendantContainerSelector.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

struct DescendantContainerSelector: Selector {
    
    static let kind = SelectorKind(Self.self)
    
    private enum State {
        
        case waitingForMatch
        case waitingForElementEnd(depth: Int)
        
    }
    
    private var pendingDepths = Stack<Int>(initialCapacity: 4)
    
    func deinitialize() {
        pendingDepths.deinitialize()
    }
    
    mutating func process(event: borrowing AnyContextualizedEvent, usingStartCondition startCondition: (borrowing AnyContextualizedEvent) throws -> Bool) rethrows -> SelectionEvent {
        //  NOTE: This assumes start condition is always for a container (element) event,
        //  and that the next event at the same depth is its ending event
        
        if try startCondition(event) {
            pendingDepths.push(event.context.depth)
            
            return .matchedContainer(.atStart)
        }
        
        if let lastDepth = pendingDepths.last?.pointee {
            if event.context.depth == lastDepth {
                pendingDepths.pop()
                
                return .matchedContainer(.atEnd)
            }
            
            return .matchedContainer(.within)
        }
        
        return .unmatched
    }
    
}

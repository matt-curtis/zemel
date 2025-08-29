//
//  ChildContainerSelector.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

struct ChildContainerSelector: Selector {
    
    static let kind = SelectorKind(Self.self)
    
    private enum State {
        
        case waitingForMatch
        case waitingForMatchEnd(depth: Int)
        case waitingForIgnoredContainerToEnd(depth: Int)
        
    }
    
    private var state: State = .waitingForMatch
    
    func deinitialize() { }
    
    mutating func process(event: borrowing AnyContextualizedEvent, usingStartCondition startCondition: (borrowing AnyContextualizedEvent) throws -> Bool) rethrows -> SelectionEvent {
        switch state {
            case .waitingForMatch:
                if try startCondition(event) {
                    state = .waitingForMatchEnd(depth: event.context.depth)
                    
                    return .matchedContainer(.atStart)
                } else if event.isElementStart {
                    state = .waitingForIgnoredContainerToEnd(depth: event.context.depth)
                }
                
                return .unmatched
                
            case .waitingForMatchEnd(let depth):
                if event.context.depth == depth {
                    state = .waitingForMatch
                    
                    return .matchedContainer(.atEnd)
                }
                
                return .matchedContainer(.within)
                
            case .waitingForIgnoredContainerToEnd(depth: let depth):
                if event.context.depth == depth {
                    state = .waitingForMatch
                }
                
                return .unmatched
        }
    }
    
}

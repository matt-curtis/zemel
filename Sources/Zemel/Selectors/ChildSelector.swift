//
//  ChildSelector.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

struct ChildSelector: Selector {
    
    static let kind = SelectorKind(Self.self)
    
    private enum State {
        
        case waitingForMatch
        case waitingForIgnoredContainerToEnd(depth: Int)
        
    }
    
    private var state: State = .waitingForMatch
    
    func deinitialize() { }
    
    mutating func process(event contextualizedEvent: borrowing AnyContextualizedEvent, usingCondition condition: (borrowing AnyContextualizedEvent) -> Bool) -> SelectionEvent {
        switch state {
            case .waitingForMatch:
                if contextualizedEvent.isElementStart {
                    state = .waitingForIgnoredContainerToEnd(depth: contextualizedEvent.context.depth)
                } else if condition(contextualizedEvent) {
                    state = .waitingForMatch
                    
                    return .matchedNode
                }
                
                return .unmatched
                
            case .waitingForIgnoredContainerToEnd(depth: let depth):
                if contextualizedEvent.isElementEnd(atDepth: depth) {
                    state = .waitingForMatch
                }
                
                return .unmatched
        }
    }
    
}

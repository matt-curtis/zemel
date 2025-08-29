//
//  DescendantSelector.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

struct DescendantSelector: Selector {
    
    static let kind = SelectorKind(Self.self)
    
    func deinitialize() { }
    
    mutating func process(event contextualizedEvent: borrowing AnyContextualizedEvent, usingCondition condition: (borrowing AnyContextualizedEvent) -> Bool) -> SelectionEvent {
        condition(contextualizedEvent) ? .matchedNode : .unmatched
    }
    
}

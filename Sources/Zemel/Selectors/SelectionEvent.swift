//
//  SelectionEvent.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

enum SelectionEvent: Equatable {
    
    enum ContainerMatchEvent: Equatable {

        case atStart
        case within
        case atEnd

    }
    
    case unmatched
    case matchedNode
    case matchedContainer(ContainerMatchEvent)
    
    var appropriateBodyExecution: RoutineExpressionExecution? {
        switch self {
            case .matchedContainer(.atStart): .userHandlers
            case .matchedContainer(.within): .selectors
            case .matchedContainer(.atEnd): .parentEndSelectors
            case .matchedNode: .userHandlers
            case .unmatched: nil
        }
    }
    
}

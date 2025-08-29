//
//  RoutineExpressionExecution.swift
//  Zemel
//
//  Created by Matt Curtis on 3/8/25.
//

enum RoutineExpressionExecution {
    
    case any, none, selectors, parentEndSelectors, userHandlers
    
    var allowsSelectors: Bool {
        self == .any || self == .selectors
    }

    var allowsParentEndSelectors: Bool {
        self == .any || self == .parentEndSelectors
    }

    var allowsUserHandlers: Bool {
        self == .any || self == .userHandlers
    }
    
}

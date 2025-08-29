//
//  Conditions.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

enum Conditions {
    
    static func isText(_ contextualizedEvent: borrowing AnyContextualizedEvent) -> Bool {
        contextualizedEvent.isText
    }
    
    static func condition(_ userCondition: () throws -> Bool, isTrueForElementStart contextualizedEvent: borrowing AnyContextualizedEvent) rethrows -> Bool {
        try contextualizedEvent.isElementStart && userCondition()
    }
    
    static func event(_ contextualizedEvent: borrowing AnyContextualizedEvent, startsElementMatchingUserGivenName userGivenName: borrowing UnsafeName) -> Bool {
        switch contextualizedEvent.event {
            case .elementStart(let elementStartEvent):
                //  Compare namespaces, but only if the user-given name has one:
                
                if let userNSURIString = userGivenName.unsafeNSURIString {
                    if elementStartEvent.name.unsafeNSURIString?.equals(userNSURIString) != true {
                        return false
                    }
                }
                
                //  Compare local names:
                
                return userGivenName.unsafeLocalNameString.equals(
                    elementStartEvent.name.unsafeLocalNameString
                )
                
            default: return false
        }
    }
    
}

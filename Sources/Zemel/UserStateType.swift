//
//  UserStateType.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

@usableFromInline
struct UserStateType {
    
    private let id: ObjectIdentifier
    
    @usableFromInline
    init(id: ObjectIdentifier) {
        self.id = id
    }
    
    @inlinable
    init<T>(for type: T.Type) {
        self.init(id: ObjectIdentifier(type))
    }
    
    func check(against other: UserStateType) {
        if id != other.id {
            preconditionFailure("User state type doesn't match type of stored state. This suggests an API is being misused in some way.")
        }
    }
    
}

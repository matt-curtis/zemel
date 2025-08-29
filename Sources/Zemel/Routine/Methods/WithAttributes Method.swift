//
//  WithAttributes.swift
//  Zemel
//
//  Created by Matt Curtis on 7/18/25.
//

extension RoutineMethods {
    
    public struct WithAttributes: ~Copyable {
        
        let ctx: UnsafeRoutineContext
        
        /// Creates an attribute iterator and passes it to the given closure.
        ///
        /// - Throws: An error if the current node isn't an element.
        
        public func callAsFunction(body: (borrowing AttributeIterator) throws -> Void) throws {
            try ctx.borrowingExpectedElementStartEvent {
                guard var rawIterator = AttributeIterator.Raw(over: $0.attributes) else { return }
                
                try withUnsafeMutablePointer(to: &rawIterator) {
                    try body(AttributeIterator(pointer: $0))
                }
            }
        }
        
    }
    
}

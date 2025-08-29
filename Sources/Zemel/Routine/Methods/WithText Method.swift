//
//  WithText.swift
//  Zemel
//
//  Created by Matt Curtis on 7/18/25.
//

extension RoutineMethods {
    
    public struct WithText: ~Copyable {
        
        let ctx: UnsafeRoutineContext
        
        /// Calls the given closure with a buffer containing the UTF-8 text content of the current text node.
        ///
        /// - Throws: An error if the current node is not a text node.
        /// - Warning: The buffer passed as an argument to `body` is valid only during the execution of this method.
        /// Do not store, mutate, or return the pointer for later use.
        
        public func callAsFunction(body: (borrowing UnsafeBufferPointer<UInt8>) throws -> Void) throws {
            try ctx.borrowingExpectedTextEvent { try body($0.unsafeText.asBuffer()) }
        }
        
    }
    
}

//
//  Handle Method.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

extension RoutineMethods {
    
    public struct Handle: ~Copyable {
        
        let ctx: UnsafeRoutineContext
        
        /// Invokes the given closure when an element is first selected.
        
        public func callAsFunction(body: () throws -> Void) rethrows -> VoidRoutineBody {
            if ctx.execution(\.allowsUserHandlers) {
                try body()
            }
            
            return .init()
        }
        
    }
    
}

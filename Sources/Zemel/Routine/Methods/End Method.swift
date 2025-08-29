//
//  End Method.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

extension RoutineMethods {
    
    public struct End: ~Copyable {
        
        let ctx: UnsafeRoutineContext
        
        /// Invokes `body` when a previously selected element ends.
        
        public func callAsFunction(body: () throws -> Void) rethrows -> VoidRoutineBody {
            if ctx.execution(\.allowsParentEndSelectors) {
                try ctx.withExecutionLimited(to: .none) {
                    try body()
                }
            }
            
            return .init()
        }
        
    }
    
}

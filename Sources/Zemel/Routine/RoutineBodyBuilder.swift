//
//  RoutineBodyBuilder.swift
//  Zemel
//
//  Created by Matt Curtis on 3/8/25.
//

/// Builds the body of a `Routine`.

@resultBuilder
public struct RoutineBodyBuilder {
    
    public static func buildExpression<T: RoutineBody>(_ expression: T) -> RoutineBodies<T> {
        .init()
    }
    
    public static func buildExpression<T>(_ expression: @autoclosure () -> T) -> RoutineBodies<VoidRoutineBody> {
        UnsafeRoutineContext.executeUserHandlerExpressionIfAllowed {
            _ = expression()
        }
        
        return .init()
    }
    
    public static func buildBlock<each T: RoutineBody>(_ components: repeat RoutineBodies<each T>) -> RoutineBodies<repeat each T> {
        .init()
    }
    
}

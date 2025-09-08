//
//  Select Method.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

extension RoutineMethods {
    
    public struct Select: ~Copyable {
        
        //  MARK: - Typealiases
        
        @usableFromInline
        typealias Deinitializer = (UnsafeMutableRawPointer) -> Void
        
        
        //  MARK: - Properties
        
        let ctx: UnsafeRoutineContext
        
        
        //  MARK: - Helper methods
        
        @usableFromInline
        func withUnintializedUserStateForNode<T>(at index: Int, body: (borrowing UnintializedSelectorState<T>) throws -> Void) throws {
            try assertNoReferencesEscape("State references must not escape their immediate context") {
                newToken in
                
                try body(UnintializedSelectorState(
                    ctx: ctx,
                    nodeIndex: index,
                    referenceCountToken: newToken()
                ))
            }
        }
        
        @inlinable
        func deinitializer<T>(for: T.Type = T.self) -> Deinitializer {
            { $0.assumingMemoryBound(to: T.self).deinitialize(count: 1) }
        }
        
        @inlinable
        static func noopDeinitializer(_: UnsafeMutableRawPointer) -> Void {
            preconditionFailure("Forgot to supply deinitializer for user state!")
        }
        
        //  MARK: - Base select methods
        
        //  MARK: - Base
        
        func select<S: Selector>(
            using selector: @autoclosure () -> S,
            process: (inout S, borrowing AnyContextualizedEvent) throws -> SelectionEvent,
            body: (Int) throws -> Void,
            userStateDeinitializer: Deinitializer
        ) rethrows {
            //  Are selectors allowed to execute in the current context?
            
            guard ctx.execution(\.allowsSelectors) else {
                ctx.skipPastChildrenOfCurrentNode()
                
                return
            }
            
            //  Select
            
            let selectionEvent = try ctx.with(currentSelector: selector()) {
                selector in
                
                try ctx.borrowingEvent {
                    event in try process(&selector, event)
                }
            }
            
            //  If we're not supposed to execute the body, skip:
            
            guard let allowedExecution = selectionEvent.appropriateBodyExecution else {
                ctx.skipPastChildrenOfCurrentNode()
                
                return
            }
            
            //  Push or pop slots for whatever state the user may use,
            //  depending on the selection event
            
            let nodeIndex = ctx.nodeIndex
            
            if case .matchedContainer(.atStart) = selectionEvent {
                ctx.pushEmptyUserStateSlot(to: nodeIndex)
            }
            
            defer {
                if case .matchedContainer(.atEnd) = selectionEvent {
                    ctx.popUserStateSlot(from: nodeIndex, using: userStateDeinitializer)
                }
            }
            
            //  Execute selector body
            
            try ctx.withExecutionLimited(to: allowedExecution) {
                ctx.incrementNodeIndex()
                
                try body(nodeIndex)
            }
        }
        
        //  MARK: Children
        
        @usableFromInline
        func selectChild<T, U>(byUserCondition userCondition: () throws -> Bool, deinitializingUserStateUsing userStateDeinitializer: Deinitializer = noopDeinitializer, body: (Int) throws -> Void) rethrows -> RoutineBodyNode<T, U> {
            try select(
                using: ChildContainerSelector(),
                process: {
                    selector, event in
                    
                    try selector.process(
                        event: event,
                        usingStartCondition: {
                            try Conditions.condition(userCondition, isTrueForElementStart: $0)
                        }
                    )
                },
                body: body,
                userStateDeinitializer: userStateDeinitializer
            )
            
            return .init()
        }
        
        @usableFromInline
        func selectChild<T, U>(by name: Name, deinitializingUserStateUsing userStateDeinitializer: Deinitializer = noopDeinitializer, body: (Int) throws -> Void) rethrows -> RoutineBodyNode<T, U> {
            try select(
                using: ChildContainerSelector(),
                process: {
                    selector, event in
                    
                    selector.process(
                        event: event,
                        usingStartCondition: {
                            event in
                            
                            name.withUnsafeName {
                                Conditions.event(event, startsElementMatchingUserGivenName: $0)
                            }
                        }
                    )
                },
                body: body,
                userStateDeinitializer: userStateDeinitializer
            )
            
            return .init()
        }
        
        //  MARK: - Descendants
        
        @usableFromInline
        func selectDescendant<Content: RoutineBody, UserState>(byUserCondition userCondition: () throws -> Bool, deinitializingUserStateUsing userStateDeinitializer: Deinitializer = noopDeinitializer, body: (Int) throws -> Void) rethrows -> RoutineBodyNode<Content, UserState> {
            try select(
                using: DescendantContainerSelector(),
                process: {
                    selector, event in
                    
                    try selector.process(
                        event: event,
                        usingStartCondition: {
                            try Conditions.condition(userCondition, isTrueForElementStart: $0)
                        }
                    )
                },
                body: body,
                userStateDeinitializer: userStateDeinitializer
            )
            
            return .init()
        }
        
        @usableFromInline
        func selectDescendant<Content: RoutineBody, UserState>(by name: Name, deinitializingUserStateUsing userStateDeinitializer: Deinitializer = noopDeinitializer, body: (Int) throws -> Void) rethrows -> RoutineBodyNode<Content, UserState> {
            try select(
                using: DescendantContainerSelector(),
                process: {
                    selector, event in
                    
                    selector.process(
                        event: event,
                        usingStartCondition: {
                            event in
                            
                            name.withUnsafeName {
                                Conditions.event(event, startsElementMatchingUserGivenName: $0)
                            }
                        }
                    )
                },
                body: body,
                userStateDeinitializer: userStateDeinitializer
            )
            
            return .init()
        }
        
        //  MARK: Chains
        
        @usableFromInline
        func select<Content: RoutineBody, UserState>(using chainResult: @autoclosure () throws -> SelectorChainResult, deinitializingUserStateUsing userStateDeinitializer: Deinitializer = noopDeinitializer, body: (Int) throws -> Void) rethrows -> RoutineBodyNode<Content, UserState> {
            try select(
                using: ChainExecutingSelector(),
                process: {
                    selector, event in
                    
                    try selector.select(using: chainResult, in: ctx)
                },
                body: body,
                userStateDeinitializer: userStateDeinitializer
            )
            
            return .init()
        }
        
        
        //  MARK: - Text selection
        
        /// Selects descendant text nodes.
        
        public func callAsFunction(_ text: TextSelectorKind, body: () throws -> Void) rethrows -> VoidRoutineBody {
            
            if ctx.execution(\.allowsSelectors) {
                let isText = ctx.borrowingEvent { $0.isText }
                
                if isText {
                    try ctx.withExecutionLimited(to: .userHandlers, run: body)
                }
            }
            
            return .init()
        }
        
        
        //  MARK: - Child selection
        
        //  MARK: Condition
        
        /// Selects child elements for which the passed condition evaluates to `true`.
        
        @inlinable
        public func callAsFunction<Content: RoutineBody>(_ child: @autoclosure () throws -> Bool, @RoutineBodyBuilder body: () throws -> Content) rethrows -> RoutineBodyNode<Content, Never> {
            try selectChild(byUserCondition: child) { _ in _ = try body() }
        }
        
        /// Selects child elements for which the passed condition evaluates to `true`.
        
        @inlinable
        public func callAsFunction<Content: RoutineBody, UserState>(_ child: @autoclosure () throws -> Bool, @RoutineBodyBuilder body: (borrowing UnintializedSelectorState<UserState>) throws -> Content) rethrows -> RoutineBodyNode<Content, UserState> {
            try selectChild(
                byUserCondition: child,
                deinitializingUserStateUsing: deinitializer(for: UserState.self),
                body: { try withUnintializedUserStateForNode(at: $0) { _ = try body($0) } }
            )
        }
        
        //  MARK: Name
        
        /// Selects child elements that match the given name.
        
        @inlinable
        public func callAsFunction<Content: RoutineBody>(_ child: Name, @RoutineBodyBuilder body: () throws -> Content) rethrows -> RoutineBodyNode<Content, Never> {
            try selectChild(by: child) { _ in _ = try body() }
        }
        
        /// Selects child elements that match the given name.
        
        @inlinable
        public func callAsFunction<Content: RoutineBody, UserState>(_ child: Name, @RoutineBodyBuilder body: (borrowing UnintializedSelectorState<UserState>) throws -> Content) rethrows -> RoutineBodyNode<Content, UserState> {
            try selectChild(
                by: child,
                deinitializingUserStateUsing: deinitializer(for: UserState.self),
                body: { try withUnintializedUserStateForNode(at: $0) { _ = try body($0) } }
            )
        }
        
        
        //  MARK: - Descendant selection
        
        //  MARK: Condition
        
        /// Selects descendant elements for which the passed condition evaluates to `true`.
        
        @inlinable
        public func callAsFunction<Content: RoutineBody>(descendant: @autoclosure () throws -> Bool, @RoutineBodyBuilder body: () throws -> Content) rethrows -> RoutineBodyNode<Content, Never> {
            try selectDescendant(byUserCondition: descendant) { _ in _ = try body() }
        }
        
        /// Selects descendant elements for which the passed condition evaluates to `true`.
        
        @inlinable
        public func callAsFunction<Content: RoutineBody, UserState>(descendant: @autoclosure () throws -> Bool, @RoutineBodyBuilder body: (borrowing UnintializedSelectorState<UserState>) throws -> Content) rethrows -> RoutineBodyNode<Content, UserState> {
            try selectDescendant(
                byUserCondition: descendant,
                deinitializingUserStateUsing: deinitializer(for: UserState.self),
                body: { try withUnintializedUserStateForNode(at: $0) { _ = try body($0) } }
            )
        }
        
        //  MARK: Name
        
        /// Selects descendant elements that match the given name.
        
        @inlinable
        public func callAsFunction<Content: RoutineBody>(descendant: Name, @RoutineBodyBuilder body: () throws -> Content) rethrows -> RoutineBodyNode<Content, Never> {
            try selectDescendant(by: descendant) { _ in _ = try body() }
        }
        
        /// Selects descendant elements that match the given name.
        
        @inlinable
        public func callAsFunction<Content: RoutineBody, UserState>(descendant: Name, @RoutineBodyBuilder body: (borrowing UnintializedSelectorState<UserState>) throws -> Content) rethrows -> RoutineBodyNode<Content, UserState> {
            try selectDescendant(
                by: descendant,
                deinitializingUserStateUsing: deinitializer(for: UserState.self),
                body: { try withUnintializedUserStateForNode(at: $0) { _ = try body($0) } }
            )
        }
        
        
        //  MARK: - Selector chains
        
        //  MARK: Container selectors
        
        /// Selects elements matching the given selector.
        
        @inlinable
        public func callAsFunction<Content: RoutineBody, UserState>(_ chain: @autoclosure () throws -> ContainerSelectorChain, @RoutineBodyBuilder body: (borrowing UnintializedSelectorState<UserState>) throws -> Content) rethrows -> RoutineBodyNode<Content, UserState> {
            try select(
                using: try chain().result,
                deinitializingUserStateUsing: deinitializer(for: UserState.self),
                body: { try withUnintializedUserStateForNode(at: $0) { _ = try body($0) } }
            )
        }
        
        /// Selects elements matching the given selector.
        
        public func callAsFunction<Content: RoutineBody>(_ chain: @autoclosure () throws -> ContainerSelectorChain, @RoutineBodyBuilder body: () throws -> Content) rethrows -> RoutineBodyNode<Content, Never> {
            try select(using: try chain().result) { _ in _ = try body() }
        }
        
        //  MARK: Node selectors
        
        /// Selects nodes matching the given selector.
        
        public func callAsFunction(_ chain: @autoclosure () -> NodeSelectorChain, body: () throws -> Void) rethrows -> RoutineBodyNode<VoidRoutineBody, Never> {
            try select(using: chain().result) { _ in _ = try body() }
        }
        
    }
    
}

//
//  SelectorChain.swift
//  Zemel
//
//  Created by Matt Curtis on 4/20/25.
//

@dynamicMemberLookup
public struct SelectorChainRoot: ~Copyable {
    
    //  MARK: - Properties
    
    private let root: SelectorChain<SelectorChainKind.Container>
    
    
    //  MARK: - Init
    
    init(ctx: UnsafeRoutineContext) {
        guard let pointer = ctx.selectorChainArrayPointer else {
            preconditionFailure("Selector chains may only be used within a select(...) call")
        }
        
        self.root = .root(ctx: ctx, selectorsPointer: pointer)
    }
    
    
    //  MARK: - Methods
    
    //  MARK: Text selection
    
    /// Selects child text nodes.
    
    public func child(_ text: TextSelectorKind) -> NodeSelectorChain {
        root.child(.text)
    }
    
    /// Selects descendant text nodes.
    
    public func descendant(_ text: TextSelectorKind) -> NodeSelectorChain {
        root.descendant(.text)
    }
    
    /// Selects descendant text nodes.
    
    public func text() -> NodeSelectorChain {
        root.descendant(.text)
    }
    
    
    //  MARK: Child selection
    
    /// Selects child elements with the given name.
    ///
    /// - Note: `nil` namespaces are treated as equal to the document's root namespace.
    
    public func child(_ name: Name) -> ContainerSelectorChain {
        root.child(name)
    }
    
    /// Selects child elements with the given name.
    ///
    /// - Note: Matches elements in the document's root namespace.
    
    public subscript(dynamicMember localName: StaticString) -> ContainerSelectorChain {
        root.child(Name(localName: .staticString(localName)))
    }
    
    /// Selects child elements for which the passed condition evaluates to `true`.
    
    public func child(_ condition: @autoclosure () throws -> Bool) rethrows -> ContainerSelectorChain {
        try root.child(condition())
    }
    
    
    //  MARK: Descendant selection
    
    /// Selects descendant elements with the given name.
    ///
    /// - Note: `nil` namespaces are treated as equal to the document's root namespace.
    
    public func descendant(_ name: Name) -> ContainerSelectorChain {
        root.descendant(name)
    }
    
    /// Selects descendant elements for which the passed condition evaluates to `true`.
    
    public func descendant(_ condition: @autoclosure () throws -> Bool) rethrows -> ContainerSelectorChain {
        try root.descendant(condition())
    }
    
}

public typealias NodeSelectorChain = SelectorChain<SelectorChainKind.Node>

public typealias ContainerSelectorChain = SelectorChain<SelectorChainKind.Container>

public enum SelectorChainKind {
    
    public enum Node { }
    public enum Container { }
    
}

@usableFromInline
struct SelectorChainResult {
    
    let selectionEvent: SelectionEvent
    
    let chainLength: Int
    
}

struct CopyableSelectorChain {
    
    let ctx: UnsafeRoutineContext
    
    let selectorsPointer: UnsafeMutablePointer<AppendOnlySelectorArray>
    
    let result: SelectorChainResult
    
    init(ctx: UnsafeRoutineContext, selectorsPointer: UnsafeMutablePointer<AppendOnlySelectorArray>, result: SelectorChainResult) {
        self.ctx = ctx
        self.selectorsPointer = selectorsPointer
        self.result = result
    }
    
    func lengthened(with newSelectionEvent: SelectionEvent) -> CopyableSelectorChain {
        CopyableSelectorChain(
            ctx: ctx,
            selectorsPointer: selectorsPointer,
            result: SelectorChainResult(
                selectionEvent: newSelectionEvent,
                chainLength: result.chainLength + 1
            )
        )
    }
    
}

@dynamicMemberLookup
public struct SelectorChain<Kind>: ~Copyable {
    
    //  MARK: - Propertes
    
    private let raw: CopyableSelectorChain
    
    @usableFromInline
    var result: SelectorChainResult { raw.result }
    
    
    //  MARK: - Methods
    
    static func root(ctx: UnsafeRoutineContext, selectorsPointer: UnsafeMutablePointer<AppendOnlySelectorArray>) -> Self {
        .init(raw: CopyableSelectorChain(
            ctx: ctx,
            selectorsPointer: selectorsPointer,
            result: SelectorChainResult(
                selectionEvent: .matchedContainer(.within),
                chainLength: 0
            )
        ))
    }
    
    private func pointerToNextSelector<S: Selector>(defaultingTo defaultValue: @autoclosure () -> S) -> UnsafeMutablePointer<S> {
        //  Is there an existing selector already on the stack?
        
        if raw.selectorsPointer.pointee.hasNext {
            let (rawPointer, storedType) = raw.selectorsPointer.pointee.next()
            
            precondition(
                S.kind == storedType,
                "Selector chain mismatch! Selector chains must be constants."
            )
            
            return rawPointer.assumingMemoryBound(to: S.self)
        }
        
        //  No existing selector, grow chain:
        
        let pointer = UnsafeMutablePointer<S>.allocate(capacity: 1)
        
        pointer.initialize(to: defaultValue())
        
        raw.selectorsPointer.pointee.append(pointer: pointer, type: S.kind)
        
        return pointer
    }
    
    private func select<S: Selector, NewKind>(usingSelector defaultSelector: @autoclosure () -> S, body: (borrowing AnyContextualizedEvent, inout S) throws -> SelectionEvent) rethrows -> SelectorChain<NewKind> {
        //  Grab pointer to next selector
        
        let state = pointerToNextSelector(defaultingTo: defaultSelector())
        
        switch raw.result.selectionEvent {
            case .matchedContainer(.within):
                //  We're "inside" the currently selected container;
                //  evaluate the next selector:
                
                let selectionEvent = try raw.ctx.borrowingEvent {
                    contextualizedEvent in
                    
                    try body(contextualizedEvent, &state.pointee)
                }
                
                //  Return newly lengthened chain with selection event
                
                return .init(raw: raw.lengthened(with: selectionEvent))
                
            default:
                //  Lengthen chain in default unmatched state
                
                state.pointee = defaultSelector()
                
                return .init(raw: raw.lengthened(with: .unmatched))
        }
    }
    
}

extension SelectorChain where Kind == SelectorChainKind.Container {
    
    //  MARK: - Methods
    
    //  MARK: Text selection
    
    /// Selects child text nodes.
    
    public func child(_ text: TextSelectorKind) -> NodeSelectorChain {
        select(usingSelector: ChildSelector()) {
            contextualizedEvent, selector in
            
            selector.process(event: contextualizedEvent, usingCondition: Conditions.isText)
        }
    }
    
    /// Selects descendant text nodes.
    
    public func descendant(_ text: TextSelectorKind) -> NodeSelectorChain {
        select(usingSelector: DescendantSelector()) {
            contextualizedEvent, selector in
            
            selector.process(event: contextualizedEvent, usingCondition: Conditions.isText)
        }
    }
    
    /// Selects descendant text nodes.
    
    public func text() -> NodeSelectorChain {
        descendant(.text)
    }
    
    
    //  MARK: Child selection
    
    /// Selects child elements with the given name.
    ///
    /// - Note: `nil` namespaces are treated as equal to the document's root namespace.
    
    public func child(_ name: Name) -> ContainerSelectorChain {
        select(usingSelector: ChildContainerSelector()) {
            contextualizedEvent, selector in
            
            selector.process(
                event: contextualizedEvent,
                usingStartCondition: {
                    event in
                    
                    name.withUnsafeName {
                        Conditions.event(event, startsElementMatchingUserGivenName: $0)
                    }
                }
            )
        }
    }
    
    /// Selects child elements for which the passed condition evaluates to `true`.
    
    public func child(_ condition: @autoclosure () throws -> Bool) rethrows -> ContainerSelectorChain {
        try select(usingSelector: ChildContainerSelector()) {
            contextualizedEvent, selector in
            
            try selector.process(
                event: contextualizedEvent,
                usingStartCondition: {
                    try Conditions.condition(condition, isTrueForElementStart: $0)
                }
            )
        }
    }
    
    /// Selects child elements with the given name.
    ///
    /// - Note: Matches elements in the document's root namespace.
    
    public subscript(dynamicMember localName: StaticString) -> ContainerSelectorChain {
        child(Name(localName: .staticString(localName)))
    }
    
    
    //  MARK: Descendant selection
    
    /// Selects descendant elements with the given name.
    ///
    /// - Note: `nil` namespaces are treated as equal to the document's root namespace.
    
    public func descendant(_ name: Name) -> ContainerSelectorChain {
        select(usingSelector: DescendantContainerSelector()) {
            contextualizedEvent, selector in
            
            selector.process(
                event: contextualizedEvent,
                usingStartCondition: {
                    event in
                    
                    name.withUnsafeName {
                        Conditions.event(event, startsElementMatchingUserGivenName: $0)
                    }
                }
            )
        }
    }
    
    /// Selects descendant elements for which the passed condition evaluates to `true`.
    
    public func descendant(_ condition: @autoclosure () throws -> Bool) rethrows -> ContainerSelectorChain {
        try select(usingSelector: DescendantContainerSelector()) {
            contextualizedEvent, selector in
            
            try selector.process(
                event: contextualizedEvent,
                usingStartCondition: {
                    try Conditions.condition(condition, isTrueForElementStart: $0)
                }
            )
        }
    }
    
}

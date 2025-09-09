//
//  Methods.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

extension Routine where Self: ~Copyable {
    
    //  MARK: - Properties
    
    /// References the current selection context.
    /// - WARNING: This property is only meant for use within a `select()` method.
    /// Using or storing it outside of a `select` method will fail.
    
    public var current: SelectorChainRoot { .init(ctx: context.unsafe) }
    
    
    //  MARK: - Methods
    
    //  NOTE: We used to have a "when-otherwise" (conditional) method,
    //  but there's implications for state managment that would have to be handled —
    //  any state created in the body of a when/otherwise branch would have to be
    //  destroyed (or the condition constant, etc.) when the condition changes
    //  in order for it to be safe, otherwise it'd be possible to pause/resume
    //  selectors in invalid states.
    
    //  MARK: End
    
    /// Invokes `body` when a previously selected element ends.
    
    public func end(body: () throws -> Void) rethrows -> VoidRoutineBody {
        if context.unsafe.execution(\.allowsParentEndSelectors) {
            try context.unsafe.withExecutionLimited(to: .none) {
                try body()
            }
        }
        
        return .init()
    }
    
    //  MARK: Handle
    
    /// Invokes the given closure when an element is first selected.
    
    public func handle(body: () throws -> Void) rethrows -> VoidRoutineBody {
        if context.unsafe.execution(\.allowsUserHandlers) {
            try body()
        }
        
        return .init()
    }
    
    
    //  MARK: Attributes
    
    /// Creates an attribute iterator and passes it to the given closure.
    ///
    /// - Throws: An error if the current node isn't an element.
    
    public func withAttributes(body: (borrowing AttributeIterator) throws -> Void) throws {
        try context.unsafe.borrowingExpectedElementStartEvent {
            guard var rawIterator = AttributeIterator.Raw(over: $0.attributes) else { return }
            
            try withUnsafeMutablePointer(to: &rawIterator) {
                try body(AttributeIterator(pointer: $0))
            }
        }
    }
    
    /// Returns `true` if any attribute exists matching the given name.
    /// - Note: Element attributes defined in XML without an explicit namespace don't belong to any namespace.
    /// - Throws: An error if the current node isn't an element.
    
    public func attribute(exists name: Name) throws -> Bool {
        var didFindMatch = false
        
        try withAttributes {
            iterator in
            
            repeat {
                if iterator.has(name: name) {
                    didFindMatch = true
                    
                    break
                }
            }
            while iterator.next()
        }
        
        return didFindMatch
    }
    
    /// Returns the first element attribute matching the given name, if any.
    /// - Note: Element attributes defined in XML without an explicit namespace don't belong to any namespace.
    /// - Throws: An error if the current node isn't an element.
    
    public func attribute(_ name: Name) throws -> String? {
        try context.unsafe.borrowingExpectedElementStartEvent { $0.attributes[name] }
    }
    
    /// Finds the first attribute matching the given name, if any, and returns `true` if it has the given value.
    /// - Note: Element attributes defined in XML without an explicit namespace don't belong to any namespace.
    /// - Throws: An error if the current node isn't an element.
    
    public func attribute(_ name: Name, is value: StringSource) throws -> Bool {
        var didFindMatch = false
        
        try withAttributes {
            iterator in
            
            repeat {
                if iterator.has(name: name) {
                    if iterator.has(value: value) {
                        didFindMatch = true
                    }
                    
                    break
                }
            }
            while iterator.next()
        }
        
        return didFindMatch
    }
    
    
    //  MARK: Names
    
    /// Returns the name of the current element.
    
    public func name() throws -> Name {
        try context.unsafe.borrowingExpectedElementStartName { $0.asName() }
    }
    
    /// Returns `true` if the current element's name matches the given name.
    ///
    /// This does an exact comparison, unlike routine selectors, which treat names with a
    /// `nil` namespace as equal to the document root namespace.
    ///
    /// - Throws: An error if the current node is not an element.
    
    public func name(is other: Name) throws -> Bool {
        try context.unsafe.borrowingExpectedElementStartName { $0.equals(other) }
    }
    
    /// Returns the local name of the current element.
    ///
    /// - Throws: An error if the current node is not an element.
    
    public func localName() throws -> String {
        try name().localName.asString()
    }
    
    /// Returns `true` if the current element's local name equals the given local name.
    ///
    /// - Throws: An error if the current node is not an element.
    
    public func localName(is other: String) throws -> Bool {
        try context.unsafe.borrowingExpectedElementStartName { $0.has(localName: other) }
    }
    
    
    //  MARK: Text
    
    /// Returns the content of the current text node.
    ///
    /// - Throws: An error if the current node is not a text node.
    
    public func text() throws -> String {
        try context.unsafe.borrowingExpectedTextEvent { $0.unsafeText.asString() }
    }
    
    /// Calls the given closure with a buffer containing the UTF-8 text content of the current text node.
    ///
    /// - Throws: An error if the current node is not a text node.
    /// - Warning: The buffer passed as an argument to `body` is valid only during the execution of this method.
    /// Do not store, mutate, or return the pointer for later use.
    
    public func withText(body: (borrowing UnsafeBufferPointer<UInt8>) throws -> Void) throws {
        try context.unsafe.borrowingExpectedTextEvent {
            try body($0.unsafeText.asBuffer())
        }
    }
    
    
    //  MARK: - State
    
    @usableFromInline
    func configuredForRun(with event: borrowing AnyContextualizedEvent, body: () throws -> Void) rethrows {
        try context.unsafe.configuredForRun(with: event, body: body)
    }
    
    /// Resets and releases all context state, allowing a routine to be reused for parsing new documents.
    
    public func resetContext() {
        context.unsafe.destroyAndRecreateBacking()
    }
    
}

//
//  Methods.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

public enum RoutineMethods { }

extension Routine where Self: ~Copyable {
    
    //  MARK: - Properties
    
    /// References the current selection context.
    /// - WARNING: This property is only meant for use within a `select()` method.
    /// Using or storing it outside of a `select` method will fail.
    
    public var current: SelectorChainRoot { .init(ctx: ctx.unsafe) }
    
    
    //  MARK: - Methods
    
    //  MARK: Mutating, body-having methods
    
    //  NOTE: We used to have a "when-otherwise" (conditional) method,
    //  but there's implications for state managment that would have to be handled —
    //  any state created in the body of a when/otherwise branch would have to be
    //  destroyed (or the condition constant, etc.) when the condition changes
    //  in order for it to be safe, otherwise it'd be possible to pause/resume
    //  selectors in invalid states.
    
    public var handle: RoutineMethods.Handle { .init(ctx: ctx.unsafe) }
    
    public var select: RoutineMethods.Select { .init(ctx: ctx.unsafe) }
    
    public var end: RoutineMethods.End { .init(ctx: ctx.unsafe) }
    
    public var withAttributes: RoutineMethods.WithAttributes { .init(ctx: ctx.unsafe) }
    
    public var withText: RoutineMethods.WithText { .init(ctx: ctx.unsafe) }
    
    
    //  MARK: Attributes
    
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
        try ctx.unsafe.borrowingExpectedElementStartEvent { $0.attributes[name] }
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
        try ctx.unsafe.borrowingExpectedElementStartName { $0.asName() }
    }
    
    /// Returns `true` if the current element's name matches the given name.
    ///
    /// This does an exact comparison, unlike routine selectors, which treat names with a
    /// `nil` namespace as equal to the document root namespace.
    ///
    /// - Throws: An error if the current node is not an element.
    
    public func name(is other: Name) throws -> Bool {
        try ctx.unsafe.borrowingExpectedElementStartName { $0.equals(other) }
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
        try ctx.unsafe.borrowingExpectedElementStartName { $0.has(localName: other) }
    }
    
    
    //  MARK: Text
    
    /// Returns the content of the current text node.
    ///
    /// - Throws: An error if the current node is not a text node.
    
    public func text() throws -> String {
        try ctx.unsafe.borrowingExpectedTextEvent { $0.unsafeText.asString() }
    }
    
}

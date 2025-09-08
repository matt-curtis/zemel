//
//  Name.swift
//  Zemel
//
//  Created by Matt Curtis on 1/12/25.
//

/// Represents an XML namespace.

public struct Namespace: Equatable, ExpressibleByStringLiteral, CustomDebugStringConvertible {
    
    //  MARK: - Properties
    
    /// The raw URI this namespace represents.
    
    public var uri: StringSource
    
    public var debugDescription: String {
        """
        Namespace(uri: "\(uri.asString())")
        """
    }
    
    
    //  MARK: - Init
    
    public init(_ uri: StringSource) {
        self.uri = uri
    }
    
    public init?(_ uri: StringSource?) {
        if let uri {
            self.uri = uri
        } else {
            return nil
        }
    }
    
    public init(_ localName: String) {
        self.uri = .string(localName)
    }
    
    public init(stringLiteral value: StaticString) {
        self.uri = .staticString(value)
    }
    
    
    //  MARK: - Methods
    
    /// Returns a `Name` in this namespace with the given local name.
    
    public subscript(_ localName: StringSource) -> Name {
        .init(ns: self, localName: localName)
    }
    
    /// Returns a `Name` in this namespace with the given local name.
    
    public subscript(dynamicMember localName: StaticString) -> Name {
        self[.staticString(localName)]
    }
    
    public func equals(ns otherNS: String) -> Bool {
        uri.withUnsafeStringPointer { $0.equals(otherNS) }
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.uri.withUnsafeStringPointer {
            a in
            
            rhs.uri.withUnsafeStringPointer {
                b in
                
                a.equals(b)
            }
        }
    }
    
}

/// A fully qualified name associating a namespace uri and local name.
///
/// - Note: Names created from string literals have `nil` namespaces.

public struct Name: Equatable, ExpressibleByStringLiteral, CustomDebugStringConvertible {
    
    //  MARK: - Properties
    
    public var ns: Namespace?
    
    public var localName: StringSource
    
    
    //  MARK: - Init
    
    public init(ns: Namespace? = nil, localName: StringSource) {
        self.ns = ns
        self.localName = localName
    }
    
    public init(_ localName: StringSource) {
        self.ns = nil
        self.localName = localName
    }
    
    public init(_ localName: String) {
        self.ns = nil
        self.localName = .string(localName)
    }
    
    public init(stringLiteral value: StaticString) {
        self.ns = nil
        self.localName = .staticString(value)
    }
    
    
    //  MARK: - Methods
    
    public var debugDescription: String {
        """
        Name(ns: \(ns.debugDescription), localName: "\(localName.asString())")
        """
    }
    
    public static func == (lhs: Name, rhs: Name) -> Bool {
        lhs.withUnsafeName { $0.equals(rhs) }
    }
    
    public func has(ns otherNS: Namespace, andLocalName otherLocalName: String) -> Bool {
        withUnsafeName { $0.has(ns: otherNS, andLocalName: otherLocalName) }
    }
    
    public func has(localName otherLocalName: String) -> Bool {
        withUnsafeName { $0.has(localName: otherLocalName) }
    }
    
    public func has(ns otherNS: Namespace) -> Bool {
        withUnsafeName { $0.has(ns: otherNS) }
    }
    
    func withUnsafeName<R>(body: (borrowing UnsafeName) throws -> R) rethrows -> R {
        try localName.withUnsafeStringPointer {
            localNamePtr in
            
            if let ns {
                try ns.uri.withUnsafeStringPointer {
                    nsURIPtr in
                    
                    try body(
                        UnsafeName(
                            unsafeNSURIString: nsURIPtr,
                            unsafeLocalNameString: localNamePtr
                        )
                    )
                }
            } else {
                try body(
                    UnsafeName(
                        unsafeNSURIString: nil,
                        unsafeLocalNameString: localNamePtr
                    )
                )
            }
        }
    }
    
}

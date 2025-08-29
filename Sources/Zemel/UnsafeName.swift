//
//  UnsafeName.swift
//  Zemel
//
//  Created by Matt Curtis on 1/13/25.
//

struct UnsafeName {
    
    let unsafeNSURIString: UnsafeStringPointer?
    
    let unsafeLocalNameString: UnsafeStringPointer
    
    init(unsafeNSURIString: UnsafeStringPointer?, unsafeLocalNameString: UnsafeStringPointer) {
        self.unsafeNSURIString = unsafeNSURIString
        self.unsafeLocalNameString = unsafeLocalNameString
    }
    
    var hasNS: Bool { unsafeNSURIString != nil }
    
    func ns() -> Namespace? {
        nsURI().map { Namespace($0) }
    }
    
    func asName() -> Name {
        Name(ns: ns(), localName: .string(unsafeLocalNameString.asString()))
    }
    
    func nsURI() -> String? {
        unsafeNSURIString?.asString()
    }
    
    func localName() -> String {
        unsafeLocalNameString.asString()
    }
    
    func has(localName otherLocalName: String) -> Bool {
        unsafeLocalNameString.equals(otherLocalName)
    }
    
    func has(ns otherNS: Namespace) -> Bool {
        if let unsafeNSURIString {
            return otherNS.uri.withUnsafeStringPointer {
                otherPtr in
                
                unsafeNSURIString.equals(otherPtr)
            }
        }
        
        return false
    }
    
    func has(ns: Namespace, andLocalName localName: String) -> Bool {
        has(localName: localName) && has(ns: ns)
    }
    
    func equals(_ otherName: Name) -> Bool {
        let otherHasNS = otherName.ns != nil
        
        if hasNS != otherHasNS {
            return false
        }
        
        return otherName.withUnsafeName {
            otherUnsafeName in
            
            if let nsURI = unsafeNSURIString, let otherNSURI = otherUnsafeName.unsafeNSURIString {
                if !nsURI.equals(otherNSURI) {
                    return false
                }
            }
            
            return unsafeLocalNameString.equals(otherUnsafeName.unsafeLocalNameString)
        }
    }
    
}

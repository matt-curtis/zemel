//
//  UnsafeAttributes.swift
//  Zemel
//
//  Created by Matt Curtis on 1/12/25.
//

import libxml2
    
struct UnsafeAttribute: ~Copyable {
    
    public let name: UnsafeName
    
    let unsafeValue: UnsafeStringPointer
    
    init(name: consuming UnsafeName, value: UnsafeStringPointer) {
        self.name = name
        self.unsafeValue = value
    }
    
}

struct UnsafeAttributes {
    
    /// An array of [ localname, prefix, URI, value start, value end... ] pointers
    
    let ptr: UnsafePointer<UnsafePointer<xmlChar>?>?
    
    let count: Int
    
    subscript(_ name: Name) -> String? {
        for i in 0..<count {
            guard let attribute = attribute(at: i) else { continue }
            
            if attribute.name.equals(name) {
                return attribute.unsafeValue.asString()
            }
        }
        
        return nil
    }
    
    func attribute(at attributeIndex: Int) -> UnsafeAttribute? {
        guard let ptr else { return nil }
        
        let elementPerAttribute = 5
        
        func get(_ localElementIndex: Int) -> UnsafePointer<xmlChar>? {
            let absoluteElementIndex = (attributeIndex * elementPerAttribute) + localElementIndex
            
            return ptr[absoluteElementIndex]
        }
        
        guard
            let localNamePtr = get(0),
            let valueStartPtr = get(3),
            let valueEndPtr = get(4)
        else {
            return nil
        }
        
        let nsURIPtr = get(2)
        
        let valueLength = valueStartPtr.distance(to: valueEndPtr)
        
        return UnsafeAttribute(
            name: UnsafeName(
                unsafeNSURIString: .init(nullTerminated: nsURIPtr),
                unsafeLocalNameString: .init(nullTerminated: localNamePtr)
            ),
            value: .init(valueStartPtr, length: valueLength)
        )
    }
    
}

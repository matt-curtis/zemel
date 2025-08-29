//
//  UnsafePrefixedNamespaces.swift
//  Zemel
//
//  Created by Matt Curtis on 1/15/25.
//

import libxml2

struct UnsafePrefixedNamespace {
    
    let prefix: UnsafeNullTerminatedStringPointer?
    
    let uri: UnsafeNullTerminatedStringPointer
    
}

struct UnsafePrefixedNamespaces: Sequence {
    
    typealias Pointer = UnsafePointer<UnsafePointer<xmlChar>?>
    
    let ptr: Pointer
    
    let count: Int
    
    init(ptr: Pointer, count: Int) {
        self.ptr = ptr
        self.count = count
    }
    
    init?(ptr: Pointer?, count: Int) {
        guard let ptr else { return nil }
        
        self.ptr = ptr
        self.count = count
    }
    
    func makeIterator() -> AnyIterator<UnsafePrefixedNamespace> {
        var namespaceIndex = 0
        
        return AnyIterator {
            [count, ptr] in
            
            while namespaceIndex < count {
                defer { namespaceIndex += 1 }
                
                let tuple = Self.tuple(at: namespaceIndex, in: ptr)
                
                if let uri = tuple.uri {
                    return Element(prefix: tuple.prefix, uri: uri)
                }
            }
            
            return nil
        }
    }
    
    private static func tuple(at index: Int, in pointer: Pointer) -> (prefix: UnsafeNullTerminatedStringPointer?, uri: UnsafeNullTerminatedStringPointer?) {
        let realIndex = index * 2
        
        let prefixPtr = pointer[realIndex]
        let uriPtr = pointer[realIndex + 1]
        
        return (
            .init(prefixPtr),
            .init(uriPtr)
        )
    }
    
    func findFirstUnprefixedNamespaceFast() -> UnsafePrefixedNamespace? {
        for namespaceIndex in 0..<count {
            let tuple = Self.tuple(at: namespaceIndex, in: ptr)
            
            if tuple.prefix == nil {
                if let uriPtr = tuple.uri {
                    return Element(prefix: tuple.prefix, uri: uriPtr)
                }
                
                break
            }
        }
        
        return nil
    }
    
}

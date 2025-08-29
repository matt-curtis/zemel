//
//  AttributeIterator.swift
//  Zemel
//
//  Created by Matt Curtis on 6/24/25.
//

/// Provides an advanceable interface for an element's attributes.

public struct AttributeIterator: ~Copyable {
    
    //  MARK: - Properties
    
    private let pointer: UnsafeMutablePointer<Raw>
    
    
    //  MARK: - Init
    
    init(pointer: UnsafeMutablePointer<Raw>) {
        self.pointer = pointer
    }
    
    
    //  MARK: - Methods
    
    /// Returns the current attribute's name.
    ///
    /// - Note: Attributes without explicit namespaces have a `nil` namespace.
    
    public func name() -> Name {
        pointer.pointee.attribute.name.asName()
    }
    
    /// Returns the current attribute's value.
    
    public func value() -> String {
        pointer.pointee.attribute.unsafeValue.asString()
    }
    
    /// Returns true if the current attribute's name matches the given name exactly.
    ///
    /// - Note: Attributes without explicit namespaces have a `nil` namespace.
    
    public func has(name otherName: Name) -> Bool {
        pointer.pointee.attribute.name.equals(otherName)
    }
    
    /// Returns `true` if the attribute value equals the given value.
    
    public func has(value otherValue: StringSource) -> Bool {
        otherValue.withUnsafeStringPointer {
            pointer.pointee.attribute.unsafeValue.equals($0)
        }
    }
    
    /// Advances to the next attribute.
    ///
    /// - Returns: `true` if another attribute exists after the current one that could be advanced to, `false` otherwise.
    
    public func next() -> Bool {
        pointer.pointee.next()
    }
    
}

extension AttributeIterator {
    
    struct Raw: ~Copyable {
        
        //  MARK: - Properties
        
        private let attributes: UnsafeAttributes
        
        fileprivate var attribute: UnsafeAttribute
        
        private var index: Int
        
        
        //  MARK: - Init
        
        private init(attributes: UnsafeAttributes, index: Int, attribute: consuming UnsafeAttribute) {
            self.attributes = attributes
            self.index = index
            self.attribute = attribute
        }
        
        init?(over attributes: UnsafeAttributes) {
            for i in 0..<attributes.count {
                if let attribute = attributes.attribute(at: i) {
                    self.init(attributes: attributes, index: i, attribute: consume attribute)
                    
                    return
                }
            }
            
            return nil
        }
        
        
        //  MARK: - Methods
        
        mutating func next() -> Bool {
            let nextIndex = index + 1
            
            for i in nextIndex..<attributes.count {
                guard let attribute = attributes.attribute(at: i) else { continue }
                
                self.index = i
                self.attribute = attribute
                
                return true
            }
            
            return false
        }
        
    }
    
}

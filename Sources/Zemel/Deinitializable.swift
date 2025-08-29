//
//  Deinitializable.swift
//  Zemel
//
//  Created by Matt Curtis on 6/4/25.
//

/// Identifies a type as deinitializable.

protocol Deinitializable {
    
    mutating func deinitialize()
    
}

//
//  Selector.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

protocol Selector: Deinitializable {
    
    static var kind: SelectorKind { get }
    
}

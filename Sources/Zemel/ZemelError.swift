//
//  ZemelError.swift
//  Zemel
//
//  Created by Matt Curtis on 2/18/25.
//

public enum ZemelError: Error {
    
    case unknown
    case parsing(line: Int, column: Int, message: String)
    case expectedTextNode
    case expectedElementNode
    
}

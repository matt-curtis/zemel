//
//  StringSource.swift
//  Zemel
//
//  Created by Matt Curtis on 6/18/25.
//

/// Holds a data type that can be used to construct a string.
/// Meant to provide faster alternatives to `String`.

public enum StringSource: ExpressibleByStringLiteral {
    
    case string(String)
    case staticString(StaticString)
    case pointer(UnsafePointer<UInt8>, length: Int)
    case nullTerminatedPointer(UnsafePointer<UInt8>)
    
    
    public init(stringLiteral staticString: StaticString) {
        self = .staticString(staticString)
    }
    
    public init(_ string: String) {
        self = .string(string)
    }
    
    public init(_ staticString: StaticString) {
        self = .staticString(staticString)
    }
    
    public func asString() -> String {
        switch self {
            case .string(let string):
                string
                
            case .staticString(let staticString):
                staticString.withUTF8Buffer {
                    String(decoding: $0, as: UTF8.self)
                }
                
            case .pointer(let pointer, length: let length):
                String(
                    decoding: UnsafeBufferPointer(start: pointer, count: length),
                    as: UTF8.self
                )
                
            case .nullTerminatedPointer(let pointer):
                String(cString: pointer)
        }
    }
    
    func withUnsafeStringPointer<R>(_ body: (borrowing UnsafeStringPointer) throws -> R) rethrows -> R {
        switch self {
            case .string(let string):
                try UnsafeStringPointer.with(string: string, body: body)
                
            case .staticString(let staticString):
                try UnsafeStringPointer.with(staticString: staticString, body: body)
            
            case .pointer(let pointer, length: let length):
                try body(UnsafeStringPointer(pointer, length: length))
                
            case .nullTerminatedPointer(let pointer):
                try body(UnsafeStringPointer(nullTerminated: pointer))
        }
    }
    
}

//
//  UnsafeStringPointer.swift
//  Zemel
//
//  Created by Matt Curtis on 1/12/25.
//

import Darwin

//  Note: All pointers here are assumed to be pointers to UTF-8 buffers,
//  just null-terminated (or unterminated).
//  libxml's xmlChar* is a pointer to a utf8 buffer:
//  https://mail.gnome.org/archives/xml/2009-December/msg00043.html

struct UnsafeStringPointer {
    
    let raw: UnsafePointer<UInt8>
    
    let length: Int
    
    public init(_ raw: UnsafePointer<UInt8>, length: Int) {
        self.raw = raw
        self.length = length
    }
    
    init?(_ raw: UnsafePointer<UInt8>?, length: Int) {
        guard let raw else { return nil }
        
        self.init(raw, length: length)
    }
    
    init(nullTerminated raw: UnsafePointer<UInt8>) {
        self.init(raw, length: strlen(raw))
    }
    
    init?(nullTerminated raw: UnsafePointer<UInt8>?) {
        guard let raw else { return nil }
        
        self.init(raw, length: strlen(raw))
    }
    
    static func with<R>(string: String, body: (UnsafeStringPointer) throws -> R) rethrows -> R {
        try string.withCString {
            cString in
                
            try cString.withMemoryRebound(to: UInt8.self, capacity: string.utf8.count) {
                try body(UnsafeStringPointer($0, length: string.utf8.count))
            }
        }
    }
    
    static func with<R>(staticString: StaticString, body: (UnsafeStringPointer) throws -> R) rethrows -> R {
        if staticString.hasPointerRepresentation {
            try body(UnsafeStringPointer(
                staticString.utf8Start,
                length: staticString.utf8CodeUnitCount
            ))
        } else {
            try withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 4) {
                buffer in
                
                _ = buffer.initialize(fromContentsOf: staticString.unicodeScalar.utf8)
                
                defer {
                    buffer.deinitialize()
                }
                
                return try body(UnsafeStringPointer(buffer.baseAddress!, length: 4))
            }
        }
    }
    
    func asBuffer() -> UnsafeBufferPointer<UInt8> {
        UnsafeBufferPointer(start: raw, count: length)
    }
    
    func asString() -> String {
        String(decoding: asBuffer(), as: UTF8.self)
    }
    
    func equals(_ otherString: String) -> Bool {
        guard otherString.utf8.count == length else { return false }
        
        return otherString.withCString {
            otherPtr in memcmp(raw, otherPtr, length) == 0
        }
    }
    
    func equals(_ otherString: UnsafeStringPointer) -> Bool {
        if otherString.length != length {
            return false
        }
        
        return memcmp(raw, otherString.raw, length) == 0
    }
    
    func equals(_ otherString: UnsafeNullTerminatedStringPointer) -> Bool {
        //  Assuming:
        //  - This string does not include a null-terminator (which it shouldn't), and
        //  - The other string is null-terminated,
        //  we can safely strncmp up to the known length:
        
        if strncmp(raw, otherString.raw, length) == 0 {
            //  Both strings are equal over the known length.
            //  Next, confirm that the null-terminated string actually ends here:
            
            let expectedTerminator = otherString.raw[length]
            
            if expectedTerminator == 0 {
                return true
            }
        }
        
        return false
    }
    
    func copy() -> UnsafeStringPointer {
        let new = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        
        new.initialize(from: raw, count: length)
        
        return .init(new, length: length)
    }
    
}

struct UnsafeNullTerminatedStringPointer {
    
    let raw: UnsafePointer<UInt8>
    
    init(_ raw: UnsafePointer<UInt8>) {
        self.raw = raw
    }
    
    init?(_ raw: UnsafePointer<UInt8>?) {
        guard let raw else { return nil }
        
        self.init(raw)
    }
    
    func asString() -> String {
        String(cString: raw)
    }
    
    func equals(_ otherString: String) -> Bool {
        otherString.withCString { strcmp($0, raw) == 0 }
    }
    
    func equals(_ otherString: UnsafeStringPointer) -> Bool {
        otherString.equals(self)
    }
    
    func equals(_ otherString: UnsafeNullTerminatedStringPointer) -> Bool {
        strcmp(otherString.raw, raw) == 0
    }
    
    func copy() -> UnsafeNullTerminatedStringPointer {
        guard let copy = UnsafeRawPointer(strdup(raw)) else {
            preconditionFailure("strdup unexpectedly returned null pointer")
        }
        
        return .init(copy.assumingMemoryBound(to: UInt8.self))
    }
    
    func calculateLengthAndCopy() -> UnsafeStringPointer {
        let length = strlen(raw)
        let new = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        
        new.initialize(from: raw, count: length)
        
        return .init(new, length: length)
    }
    
}

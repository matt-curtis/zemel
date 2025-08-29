//
//  ReferenceCount.swift
//  Zemel
//
//  Created by Matt Curtis on 7/22/25.
//

struct ReferenceCountToken: ~Copyable {
    
    private let pointer: UnsafeMutablePointer<Int>
    
    fileprivate init(pointer: UnsafeMutablePointer<Int>) {
        self.pointer = pointer
        
        pointer.pointee += 1
    }
    
    deinit {
        pointer.pointee -= 1
    }
    
    func newToken() -> ReferenceCountToken {
        ReferenceCountToken(pointer: pointer)
    }
    
}

/// Asserts that reference tokens created in `body` don't escape.
/// (Once `~Escapable` is no longer experimental it can replace this.)

@available(swift, deprecated: 6.2, message: "Replace with ~Escapable")
func assertNoReferencesEscape(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line, _ body: (() -> ReferenceCountToken) throws -> Void) rethrows {
    var rawReferenceCount = 0
    
    defer {
        precondition(
            rawReferenceCount == 0,
            message(),
            file: file,
            line: line
        )
    }
    
    try withUnsafeMutablePointer(to: &rawReferenceCount) {
        pointer in
        
        try body({ ReferenceCountToken(pointer: pointer) })
    }
}

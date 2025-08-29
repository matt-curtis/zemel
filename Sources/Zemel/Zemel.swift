//
//  Zemel.swift
//  Zemel
//
//  Created by Matt Curtis on 3/8/25.
//

import Foundation
import libxml2

/// Parses XML using a given parse routine.

public struct Zemel: ~Copyable {
    
    //  MARK: - Types
    
    struct State: ~Copyable {
        
        var depth = 0
        
        var rootDefaultNS: UnsafeStringPointer?
        
        private let errorPointer: UnsafeMutablePointer<Error?>
        
        private var hasError = false
        
        var error: Error? { errorPointer.pointee }
        
        mutating func setError(_ error: Error) {
            errorPointer.pointee = error
            hasError = true
        }
        
        func throwErrorIfAny() throws {
            if hasError, let error = error {
                throw error
            }
        }
        
        public init() {
            let errorPointer = UnsafeMutablePointer<Error?>.allocate(capacity: 1)
            
            errorPointer.initialize(to: nil)
            
            self.errorPointer = errorPointer
        }
        
        deinit {
            errorPointer.deinitialize(count: 1)
            errorPointer.deallocate()
            
            //  This assumes root default ns is an owned, trivial (utf8) buffer,
            //  and can be safely deallocated this way.
            
            rootDefaultNS?.raw.deallocate()
        }
        
    }
    
    public struct ParseMethod: ~Copyable {
        
        let zemelPointer: UnsafeMutablePointer<Zemel>
        
        let targetedTrampolinePointer: UnsafePointer<TargetedRoutineTrampoline>
        
        /// Parses the given chunk, throwing any encountered errors.
        
        public func callAsFunction(final isFinal: Bool, chunk: UnsafeBufferPointer<CChar>) throws {
            try zemelPointer.pointee.parse(final: isFinal, chunk: chunk, using: targetedTrampolinePointer)
        }
        
        /// Parses the given chunk, throwing any encountered errors.
        
        @inlinable
        public func callAsFunction(final isFinal: Bool, chunk: String) throws {
            try chunk.withCString {
                let buffer = UnsafeBufferPointer(start: $0, count: chunk.utf8.count)
                
                try callAsFunction(final: isFinal, chunk: buffer)
            }
        }
        
        /// Parses the given chunk, throwing any encountered errors.
        
        @inlinable
        public func callAsFunction(final isFinal: Bool, chunk: Data) throws {
            try chunk.withUnsafeBytes {
                try $0.withMemoryRebound(to: CChar.self) {
                    try callAsFunction(final: isFinal, chunk: $0)
                }
            }
        }
        
    }
    
    
    //  MARK: - Properties
    
    private var state = State()
    
    private let ctxPtr: xmlParserCtxtPtr
    
    private var needsResetBeforeNextParseCall = false
    
    
    //  MARK: - Init/deinit
    
    public init() {
        var handler = Self.createXMLSAXHandler()
        
        let ctxPtr = xmlCreatePushParserCtxt(&handler, nil, nil, 0, nil)
        
        guard let ctxPtr else {
            preconditionFailure("Creating libxml2 parser context failed unexpectedly!")
        }
        
        self.ctxPtr = ctxPtr
    }
    
    deinit {
        xmlFreeParserCtxt(ctxPtr)
    }
    
    
    //  MARK: - Methods
    
    /// Calls the given closure with a method that parses XML chunks using a specific `Routine`.
    
    public mutating func using<R: Routine & ~Copyable>(_ routinePointer: UnsafeMutablePointer<R>, body: (borrowing ParseMethod) throws -> Void) rethrows {
        //  Grab the untargeted trampoline from the passed routine
        
        let untargetedTrampoline = routinePointer.pointee.ctx.untargetedTrampoline
        
        //  Set the routine's context as the current thread's context
        
        try routinePointer.pointee.ctx.unsafe.asCurrent {
            try withUnsafeMutablePointer(to: &self) {
                zemelPointer in
                
                //  Target trampoline to the passed routine and this Zemel instance
                
                try untargetedTrampoline.targeted(toZemel: zemelPointer, andRoutine: routinePointer) {
                    zemelPointer.pointee.ctxPtr.pointee.userData = UnsafeMutableRawPointer(mutating: $0)
                    
                    defer {
                        zemelPointer.pointee.ctxPtr.pointee.userData = nil
                    }
                    
                    //  Call provided body with parse method
                    
                    try body(ParseMethod(zemelPointer: zemelPointer, targetedTrampolinePointer: $0))
                }
            }
        }
    }
    
    mutating func parse(final isFinal: Bool, chunk: UnsafeBufferPointer<CChar>, using trampolinePointer: UnsafePointer<TargetedRoutineTrampoline>) throws {
        //  Reset if needed
        
        if needsResetBeforeNextParseCall {
            reset()
        }
        
        //  Convenience parse helper
        
        func parseChunk(final isFinalChunk: Bool, offset: Int, size: Int32) -> Bool {
            let result = xmlParseChunk(
                ctxPtr, /* xml parser ctx */
                chunk.baseAddress?.advanced(by: offset), /* chunk pointer */
                Int32(size), /* chunk size */
                isFinalChunk ? 1 : 0 /* should end parsing */
            )
            
            let didSucceed = result == 0
            
            return didSucceed
        }
        
        //  Chunk and parse input if it exceeds Int32.max
        
        let maxChunkSize = Int(Int32.max)
        var didSucceed = true
        
        if chunk.count < maxChunkSize {
            didSucceed = parseChunk(final: isFinal, offset: 0, size: Int32(chunk.count))
        } else {
            var offset = 0
            
            repeat {
                defer { offset += maxChunkSize }
                
                let size = min(chunk.count - offset, maxChunkSize)
                let isFinalChunk = isFinal && offset + size == chunk.endIndex
                
                didSucceed = parseChunk(final: isFinalChunk, offset: offset, size: Int32(size))
            } while didSucceed && offset < chunk.count
        }
        
        //  If any error thrown by Zemel occured during parsing, rethrow it:
        
        try state.throwErrorIfAny()
        
        if !didSucceed {
            //  If we didn't throw the error, it came from libxml:
            
            needsResetBeforeNextParseCall = true
            
            guard let errorPtr = xmlCtxtGetLastError(ctxPtr) else {
                throw ZemelError.unknown
            }
            
            let message = String(cString: errorPtr.pointee.message)
            let line = Int(errorPtr.pointee.line)
            let column = Int(errorPtr.pointee.int2)
            
            throw ZemelError.parsing(line: line, column: column, message: message)
        }
        
        //  Final chunk; we'll need to reset state before this Zemel can be used again.
        
        if isFinal {
            needsResetBeforeNextParseCall = true
        }
    }
    
    /// Resets this Zemel instance, which allows it to be used again for parsing.
    
    public mutating func reset() {
        xmlCtxtResetPush(ctxPtr, "", 0, nil, nil)
        
        needsResetBeforeNextParseCall = false
        
        state = .init()
    }
    
    
    //  MARK: - Parsing callbacks
    
    private mutating func stopParsing(withError error: Error) {
        xmlStopParser(ctxPtr)
        
        needsResetBeforeNextParseCall = true
        state.setError(error)
    }
    
    private mutating func contextualizeThenForward(event: consuming AnyEvent, to body: (borrowing AnyContextualizedEvent) throws -> Void) {
        //  Forward contextualized event
        
        let anyContextualizedEvent = AnyContextualizedEvent(
            context: EventContext(
                depth: state.depth,
                rootDefaultNS: state.rootDefaultNS
            ),
            event: consume event
        )
        
        do {
            try body(anyContextualizedEvent)
        } catch {
            stopParsing(withError: error)
        }
    }
    
    mutating func onCharacters(
        charactersPtr: UnsafePointer<xmlChar>?,
        length: Int32,
        callRoutine: (borrowing AnyContextualizedEvent) throws -> Void
    ) {
        //  Construct and forward a text event
        
        guard let charactersPtr else { return }
        
        let event: AnyEvent = .text(
            TextEvent(text: UnsafeStringPointer(charactersPtr, length: Int(length)))
        )
        
        contextualizeThenForward(event: consume event, to: callRoutine)
    }
    
    mutating func onElementStart(
        uriPtr: UnsafePointer<xmlChar>?,
        localNamePtr: UnsafePointer<xmlChar>?,
        namespacesPtr: UnsafeMutablePointer<UnsafePointer<xmlChar>?>?,
        namespaceCount: Int32,
        attributesPtr: UnsafeMutablePointer<UnsafePointer<xmlChar>?>?,
        attributeCount: Int32,
        callRoutine: (borrowing AnyContextualizedEvent) throws -> Void
    ) {
        guard let localNamePtr else {
            assertionFailure("Encountered element start event without local name")
            
            stopParsing(withError: ZemelError.unknown)
            
            return
        }
        
        //  If this is the root element, store the default namespace, if one is defined
        
        if state.depth == 0 {
            let namespaces = UnsafePrefixedNamespaces(ptr: namespacesPtr, count: Int(namespaceCount))
            
            if let defaultNamespaceURI = namespaces?.findFirstUnprefixedNamespaceFast()?.uri {
                state.rootDefaultNS = defaultNamespaceURI.calculateLengthAndCopy()
            }
        }
        
        //  Construct event
        
        let attributes = UnsafeAttributes(ptr: attributesPtr, count: Int(attributeCount))
        let name = UnsafeName(
            unsafeNSURIString: .init(nullTerminated: uriPtr),
            unsafeLocalNameString: .init(nullTerminated: localNamePtr)
        )
        
        let event: AnyEvent = .elementStart(
            ElementStartEvent(name: name, attributes: attributes)
        )
        
        //  Forward event
        
        contextualizeThenForward(event: consume event, to: callRoutine)
        
        //  Increment depth; any next events that aren't the closing tag
        //  are descendants of this element
        
        state.depth += 1
    }
    
    mutating func onElementEnd(
        uriPtr: UnsafePointer<xmlChar>?,
        localNamePtr: UnsafePointer<xmlChar>?,
        callRoutine: (borrowing AnyContextualizedEvent) throws -> Void
    ) {
        //  Deincrement depth and forward element end event
        
        state.depth -= 1
        
        let event: AnyEvent = .elementEnd(ElementEndEvent())
        
        contextualizeThenForward(event: consume event, to: callRoutine)
    }
    
    static func createXMLSAXHandler() -> xmlSAXHandler {
        var handler = xmlSAXHandler()
        
        handler.initialized = XML_SAX2_MAGIC
        
        handler.startElementNs = {
            ctxPtr, localNamePtr, prefixPtr, uriPtr, namespaceCount, namespacesPtr, attributeCount, defaultedAttributeCount, attributesPtr in
            
            let trampoline = TargetedRoutineTrampoline(ctxPtr)
                
            trampoline.withZemel {
                $0.onElementStart(
                    uriPtr: uriPtr,
                    localNamePtr: localNamePtr,
                    namespacesPtr: namespacesPtr,
                    namespaceCount: namespaceCount,
                    attributesPtr: attributesPtr,
                    attributeCount: attributeCount,
                    callRoutine: trampoline.callRoutine
                )
            }
        }
        
        handler.endElementNs = {
            ctxPtr, localNamePtr, prefixPtr, uriPtr in
            
            let trampoline = TargetedRoutineTrampoline(ctxPtr)
            
            trampoline.withZemel {
                $0.onElementEnd(
                    uriPtr: uriPtr,
                    localNamePtr: localNamePtr,
                    callRoutine: trampoline.callRoutine
                )
            }
        }
        
        handler.characters = {
            ctxPtr, charactersPtr, length in
            
            let trampoline = TargetedRoutineTrampoline(ctxPtr)
            
            trampoline.withZemel {
                $0.onCharacters(
                    charactersPtr: charactersPtr,
                    length: length,
                    callRoutine: trampoline.callRoutine
                )
            }
        }
        
        return handler
    }

    
}

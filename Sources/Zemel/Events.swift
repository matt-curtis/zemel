//
//  Events.swift
//  Zemel
//
//  Created by Matt Curtis on 1/12/25.
//
    
struct EventContext: ~Copyable {
    
    let depth: Int
    
    let rootDefaultNS: UnsafeStringPointer?
    
}

enum AnyEvent: ~Copyable {
    
    case elementStart(ElementStartEvent)
    case elementEnd(ElementEndEvent)
    case text(TextEvent)
    
}

@usableFromInline
struct AnyContextualizedEvent: ~Copyable {
    
    let context: EventContext
    
    let event: AnyEvent
    
    init(context: consuming EventContext, event: consuming AnyEvent) {
        self.context = context
        self.event = event
    }
    
    var isElementStart: Bool {
        switch event {
            case .elementStart: true
            default: false
        }
    }
    
    var isText: Bool {
        switch event {
            case .text: true
            default: false
        }
    }
    
    func isElementEnd(atDepth depth: Int) -> Bool {
        guard context.depth == depth else { return false }
        
        return switch event {
            case .elementEnd: true
            default: false
        }
    }
    
}

struct ElementStartEvent: ~Copyable {
    
    let name: UnsafeName
    
    let attributes: UnsafeAttributes
    
    init(name: UnsafeName, attributes: UnsafeAttributes) {
        self.name = name
        self.attributes = attributes
    }
    
}

struct ElementEndEvent: ~Copyable { }

struct TextEvent: ~Copyable {
    
    let unsafeText: UnsafeStringPointer
    
    init(text: UnsafeStringPointer) {
        self.unsafeText = text
    }
    
}

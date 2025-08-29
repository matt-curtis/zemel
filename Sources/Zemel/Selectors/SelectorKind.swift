//
//  SelectorKind.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

struct SelectorKind: Equatable {
    
    private enum Raw: Equatable {
        
        case child, childContainer
        case descendant, descendantContainer
        case chain
        
    }
    
    private let raw: Raw
    
    private init(_ raw: Raw) { self.raw = raw }
    
    init(_ type: ChildSelector.Type) {
        self.init(.child)
    }
    
    init(_ type: ChildContainerSelector.Type) {
        self.init(.childContainer)
    }
    
    init(_ type: DescendantSelector.Type) {
        self.init(.descendant)
    }
    
    init(_ type: DescendantContainerSelector.Type) {
        self.init(.descendantContainer)
    }
    
    init(_ type: ChainExecutingSelector.Type) {
        self.init(.chain)
    }
    
    func deinitialize(_ rawPointer: UnsafeMutableRawPointer) {
        func deinitialize<T: Selector>(assuming type: T.Type) {
            let pointer = rawPointer.assumingMemoryBound(to: T.self)
            
            pointer.pointee.deinitialize()
            
            pointer.deinitialize(count: 1)
        }
        
        switch raw {
            case .child:
                deinitialize(assuming: ChildSelector.self)
                
            case .childContainer:
                deinitialize(assuming: ChildContainerSelector.self)
                
            case .descendant:
                deinitialize(assuming: DescendantSelector.self)
                
            case .descendantContainer:
                deinitialize(assuming: DescendantContainerSelector.self)
                
            case .chain:
                deinitialize(assuming: ChainExecutingSelector.self)
        }
    }
    
}

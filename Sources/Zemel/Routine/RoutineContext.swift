//
//  RoutineContext.swift
//  Zemel
//
//  Created by Matt Curtis on 3/8/25.
//

@preconcurrency import ZemelC

@usableFromInline
struct UnsafeRoutineContext {
    
    //  MARK: - Static
    
    private static var pointerToCurrentContext: UnsafePointer<UnsafeRoutineContext>? {
        get { UnsafePointer(zemelThreadLocalStorage?.assumingMemoryBound(to: UnsafeRoutineContext.self)) }
        set { zemelThreadLocalStorage = UnsafeMutableRawPointer(mutating: newValue) }
    }
    
    
    //  MARK: - Backing
    
    private struct Backing {
        
        struct RunSpecificState {
            
            var eventPointer: UnsafePointer<AnyContextualizedEvent>
            
            var routineExpressionExecution: RoutineExpressionExecution
            
            var selectorChainArrayPointer: UnsafeMutablePointer<AppendOnlySelectorArray>?
            
        }
        
        var nodeIndex = 0
        
        var boundsCheckedNodeIndex: Int {
            precondition(
                nodeIndex >= 0 && nodeIndex < bodyLength,
                "Node index out of bounds!"
            )
            
            return nodeIndex
        }
        
        var hasRunBefore = false
        
        var runSpecificState: RunSpecificState?
        
        let bodyDescription: RoutineBodyDescription
        
        var bodyLength: Int { bodyDescription.bounds.inclusiveLength }
        
        let nodeStateReferences: UnsafeMutablePointer<NodeStateReferences>
        
        init(bodyDescription: RoutineBodyDescription) {
            let bodyLength = bodyDescription.bounds.inclusiveLength
            
            self.nodeStateReferences = .allocate(capacity: bodyLength)
            
            for i in 0..<bodyLength {
                (self.nodeStateReferences + i).initialize(to: .init())
            }
            
            self.bodyDescription = bodyDescription
        }
        
        func deinitialize(includingBodyDescription: Bool) {
            //  TODO:
            //  Technically this wastes a bit of time dereferencing (and in the process,
            //  retaining and releasing the deinitializer) even in cases where
            //  there's no user state stored.
            //  Small potential performance win available for large bodies with lots of nodes.
            
            for i in 0..<bodyLength {
                let pointer = nodeStateReferences + i
                let userStateDeinitializer = bodyDescription.deinitializerForUserState(at: i)
                
                pointer.pointee.deinitialize(usingUserStateDeinitializer: userStateDeinitializer)
            }
            
            nodeStateReferences.deinitialize(count: bodyLength)
            nodeStateReferences.deallocate()
            
            if includingBodyDescription {
                bodyDescription.deinitialize()
            }
        }
        
    }
    
    
    //  MARK: - Properties
    
    private let pointer: UnsafeMutablePointer<Backing>
    
    var nodeIndex: Int { pointer.pointee.nodeIndex }
    
    var selectorChainArrayPointer: UnsafeMutablePointer<AppendOnlySelectorArray>? {
        pointer.pointee.runSpecificState?.selectorChainArrayPointer
    }
    
    
    //  MARK: - Init/deinit
    
    init(bodyDescription: RoutineBodyDescription) {
        let backing = Backing(bodyDescription: bodyDescription)
        
        self.pointer = .allocate(capacity: 1)
        self.pointer.initialize(to: backing)
    }
    
    func deinitialize() {
        pointer.pointee.deinitialize(includingBodyDescription: true)
        
        pointer.deinitialize(count: 1)
        pointer.deallocate()
    }
    
    
    //  MARK: - Methods
    
    //  MARK: Reset
    
    func destroyAndRecreateBacking() {
        //  Copy body description
        
        let bodyDescription = pointer.pointee.bodyDescription
        
        //  Deinitialize backing (excluding body description)
        
        pointer.pointee.deinitialize(includingBodyDescription: false)
        
        pointer.deinitialize(count: 1)
        
        //  Create new backing keeping old body description
        
        let backing = Backing(bodyDescription: bodyDescription)
        
        pointer.initialize(to: backing)
    }
    
    
    //  MARK: Backing access convenience
    
    private func use<Result: ~Copyable>(_ closure: (inout Backing) throws -> Result) rethrows -> Result {
        try closure(&pointer.pointee)
    }
    
    
    //  MARK: Node index tracking
    
    func resetNodeIndex() {
        use { $0.nodeIndex = 0 }
    }
    
    func incrementNodeIndex() {
        use { $0.nodeIndex += 1 }
    }
    
    func skipPastChildrenOfCurrentNode() {
        use {
            backing in
            
            backing.nodeIndex = backing.bodyDescription.nextIndexAfterSkipping(backing.nodeIndex)
        }
    }
    
    
    //  MARK: Errors
    
    private func preconditionFailureRegardingUsageOutsideOfRun() -> Never {
        preconditionFailure("Context APIs are unavailable outside of routine bodies.")
    }
    
    
    //  MARK: Current
    
    func asCurrent<Result>(_ body: () throws -> Result) rethrows -> Result {
        try withUnsafePointer(to: self) {
            let old = Self.pointerToCurrentContext
            
            defer { Self.pointerToCurrentContext = old }
            
            Self.pointerToCurrentContext = $0
            
            return try body()
        }
    }
    
    
    //  MARK: Execution
    
    func execution(_ executionKeyPath: (RoutineExpressionExecution) -> Bool) -> Bool {
        use { ($0.runSpecificState?.routineExpressionExecution).map(executionKeyPath) } ?? false
    }
    
    func withExecutionLimited<T>(to execution: RoutineExpressionExecution, run body: () throws -> T) rethrows -> T {
        try use {
            backing in
            
            guard let old = backing.runSpecificState?.routineExpressionExecution else {
                preconditionFailureRegardingUsageOutsideOfRun()
            }
            
            defer { backing.runSpecificState?.routineExpressionExecution = old }
            
            backing.runSpecificState?.routineExpressionExecution = execution
            
            return try body()
        }
    }
    
    static func executeUserHandlerExpressionIfAllowed(_ expression: () -> Void) {
        if let pointer = pointerToCurrentContext, pointer.pointee.execution(\.allowsUserHandlers) {
            pointer.pointee.withExecutionLimited(to: .none) {
                expression()
            }
        }
    }
    
    
    //  MARK: - Routine pre & post-run configuration
    
    @usableFromInline
    func configuredForRun(with event: borrowing AnyContextualizedEvent, body: () throws -> Void) rethrows {
        try use {
            backing in
            
            defer {
                resetNodeIndex()
                
                backing.hasRunBefore = true
                backing.runSpecificState = nil
            }
            
            try withUnsafePointer(to: event) {
                eventPointer in
                
                backing.runSpecificState = Backing.RunSpecificState(
                    eventPointer: eventPointer,
                    routineExpressionExecution: backing.hasRunBefore ? .selectors : .any
                )
                
                try body()
            }
        }
    }
    
    
    //  MARK: - Node state
    
    func with<S: Selector, R>(currentSelector initialState: @autoclosure () -> S, body: (inout S) throws -> R) rethrows -> R {
        let statePointer = use {
            backing in
            
            let nodeIndex = backing.boundsCheckedNodeIndex
            
            let stateReferencePointer = backing.nodeStateReferences + nodeIndex
            let selectorPointer = stateReferencePointer.pointee.pointerToSelector(initialValue: initialState())
            
            return selectorPointer
        }
        
        return try body(&statePointer.pointee)
    }
    
    func pushEmptyUserStateSlot(to index: Int) {
        let stateReferencePointer = use { $0.nodeStateReferences + index }
            
        stateReferencePointer.pointee.pushEmptyUserStateSlot()
    }
    
    @usableFromInline
    func uncheckedPointerToUserState(at index: Int, initializer: () throws -> UnsafeMutableRawPointer) rethrows -> UnsafeMutableRawPointer {
        let stateReferencePointer = use { $0.nodeStateReferences + index }
            
        return try stateReferencePointer.pointee.uncheckedPointerToUserState(initializer: initializer)
    }
    
    @usableFromInline
    func checkedPointerToUserState(at index: Int, initializer: () throws -> UnsafeMutableRawPointer, type: UserStateType) rethrows -> UnsafeMutableRawPointer {
        let stateReferencePointer = use { $0.nodeStateReferences + index }
        
        return try stateReferencePointer.pointee.checkedPointerToUserState(initializer: initializer, type: type)
    }
    
    func popUserStateSlot(from index: Int, using deinitializer: (UnsafeMutableRawPointer) -> Void) {
        let stateReferencePointer = use { $0.nodeStateReferences + index }
        
        stateReferencePointer.pointee.popUserStateSlot(using: deinitializer)
    }
    
    
    //  MARK: Events
    
    func borrowingEvent<T: ~Copyable>(_ body: (borrowing AnyContextualizedEvent) throws -> T) rethrows -> T {
        try use {
            backing in
            
            guard let eventPointer = backing.runSpecificState?.eventPointer else {
                preconditionFailureRegardingUsageOutsideOfRun()
            }
            
            return try body(eventPointer.pointee)
        }
    }
    
    func borrowingExpectedTextEvent<T>(body: (borrowing TextEvent) throws -> T) throws -> T {
        try borrowingEvent {
            switch $0.event {
                case .text(let textEvent):
                    return try body(textEvent)
                
                default:
                    throw ZemelError.expectedTextNode
            }
        }
    }
    
    func borrowingExpectedElementStartEvent<T>(body: (borrowing ElementStartEvent) throws -> T) throws -> T {
        try borrowingEvent {
            switch $0.event {
                case .elementStart(let elementStartEvent):
                    return try body(elementStartEvent)
                
                default:
                    throw ZemelError.expectedElementNode
            }
        }
    }
    
    func borrowingExpectedElementStartName<T>(body: (borrowing UnsafeName) throws -> T) throws -> T {
        try borrowingEvent {
            switch $0.event {
                case .elementStart(let elementStartEvent):
                    return try body(elementStartEvent.name)
                
                default:
                    throw ZemelError.expectedElementNode
            }
        }
    }
    
    func with<T>(event: borrowing AnyContextualizedEvent, body: () throws -> T) rethrows -> T {
        try use {
            backing in
            
            guard let old = backing.runSpecificState?.eventPointer else {
                preconditionFailureRegardingUsageOutsideOfRun()
            }
            
            return try withUnsafePointer(to: event) {
                eventPointer in
                
                backing.runSpecificState?.eventPointer = eventPointer
                
                defer { backing.runSpecificState?.eventPointer = old }
                
                return try body()
            }
        }
    }
    
    
    //  MARK: Selector chains
    
    func with<T>(selectorChainState pointer: UnsafeMutablePointer<AppendOnlySelectorArray>, body: () throws -> T) rethrows -> T {
        try use {
            backing in
            
            let old = backing.runSpecificState?.selectorChainArrayPointer
            
            backing.runSpecificState?.selectorChainArrayPointer = pointer
            
            defer { backing.runSpecificState?.selectorChainArrayPointer = old }
            
            return try body()
        }
    }
    
}

/// Tracks routine state.
/// `RoutineContext`s are unique to the routine type they are created for.
/// Sharing contexts between routines will result in undefined behavior.

public struct RoutineContext: ~Copyable {
    
    let unsafe: UnsafeRoutineContext
    
    let untargetedTrampoline: UntargetedRoutineTrampoline
    
    @usableFromInline
    init(untargetedTrampoline: UntargetedRoutineTrampoline, bodyDescription: RoutineBodyDescription) {
        self.unsafe = UnsafeRoutineContext(bodyDescription: bodyDescription)
        self.untargetedTrampoline = untargetedTrampoline
    }
    
    deinit {
        unsafe.deinitialize()
    }
    
    @usableFromInline
    func configuredForRun(with event: borrowing AnyContextualizedEvent, body: () throws -> Void) rethrows {
        try unsafe.configuredForRun(with: event, body: body)
    }
    
    /// Resets and releases all context state, allowing a routine to be reused for parsing new documents.
    
    public func reset() {
        unsafe.destroyAndRecreateBacking()
    }
    
}

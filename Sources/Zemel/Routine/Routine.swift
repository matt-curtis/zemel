//
//  Routine.swift
//  Zemel
//
//  Created by Matt Curtis on 3/8/25.
//

/// A type that statically describes the body of a routine.

public protocol RoutineBody: ~Copyable {
    
    /// - Warning: Implementation detail. Not meant for use.
    
    static func build(bounds: inout RoutineBodyDescription.Bounds)
    
    /// - Warning: Implementation detail. Not meant for use.
    
    static func build(description: inout RoutineBodyDescription)
    
}

/// - Warning: Implementation detail. Not meant for use.

public struct RoutineBodyDescription: Deinitializable {
    
    typealias Deinitializer = (UnsafeMutableRawPointer) -> Void
    
    struct NodeDescription {
        
        /// The first index that comes after this node and its descendants.
        
        let skipPastIndex: Int
        
    }
    
    public struct Bounds {
        
        /// The number of descendants this node has, including the node itself.
        
        @usableFromInline
        var inclusiveLength: Int
        
        @usableFromInline
        init() {
            self.inclusiveLength = 0
        }
        
    }
    
    let bounds: Bounds
    
    private let nodeDescriptions: UnsafeMutablePointer<NodeDescription>
    
    private let userStateDeinitializers: UnsafeMutablePointer<Deinitializer>
    
    private var currentNextIndex = 0
    
    @usableFromInline
    init(bounds: Bounds) {
        self.bounds = bounds
        
        self.nodeDescriptions = .allocate(capacity: bounds.inclusiveLength)
        self.userStateDeinitializers = .allocate(capacity: bounds.inclusiveLength)
    }
    
    @inlinable
    init<Body: RoutineBody>(for type: Body.Type) {
        var bounds = Bounds()
        
        Body.build(bounds: &bounds)
        
        var description = RoutineBodyDescription(bounds: bounds)
        
        Body.build(description: &description)
        
        description.assertCorrectlyBuilt()
        
        self = description
    }
    
    @usableFromInline
    func assertCorrectlyBuilt() {
        precondition(
            currentNextIndex == bounds.inclusiveLength,
            "Unable to safely initialize routine body description; description incorrectly built."
        )
    }
    
    func deinitialize() {
        nodeDescriptions.deinitialize(count: bounds.inclusiveLength)
        nodeDescriptions.deallocate()
        
        userStateDeinitializers.deinitialize(count: bounds.inclusiveLength)
        userStateDeinitializers.deallocate()
    }
    
    @usableFromInline
    mutating func didEncounterNode(
        contentLength: Int,
        userStateDeinitializer: @escaping (UnsafeMutableRawPointer) -> Void
    ) {
        precondition(
            currentNextIndex < bounds.inclusiveLength,
            "Unexpectedly encountered node in body outside of expected bounds"
        )
        
        let nodeDescription = NodeDescription(
            skipPastIndex: currentNextIndex + 1 + contentLength
        )
        
        nodeDescriptions
            .advanced(by: currentNextIndex)
            .initialize(to: nodeDescription)
        
        userStateDeinitializers
            .advanced(by: currentNextIndex)
            .initialize(to: userStateDeinitializer)
        
        currentNextIndex += 1
    }
    
    @usableFromInline
    func printDescription() {
        print("length", bounds.inclusiveLength)
        print(
            "node descriptions",
            Array(UnsafeBufferPointer(start: nodeDescriptions, count: bounds.inclusiveLength))
        )
    }
    
    func nextIndexAfterSkipping(_ index: Int) -> Int {
        nodeDescriptions[index].skipPastIndex
    }
    
    func deinitializerForUserState(at index: Int) -> (UnsafeMutableRawPointer) -> Void {
        userStateDeinitializers[index]
    }
    
}

/// An empty routine body.

public struct VoidRoutineBody: RoutineBody {
    
    @inlinable
    public static func build(bounds: inout RoutineBodyDescription.Bounds) { }
    
    @inlinable
    public static func build(description: inout RoutineBodyDescription) { }
    
}

/// A routine body node.

public struct RoutineBodyNode<Content: RoutineBody, UserState>: RoutineBody {
    
    @inlinable
    public static func build(bounds: inout RoutineBodyDescription.Bounds) {
        bounds.inclusiveLength += 1
        
        Content.build(bounds: &bounds)
    }
    
    @inlinable
    public static func build(description: inout RoutineBodyDescription) {
        var contentBounds = RoutineBodyDescription.Bounds()
        
        Content.build(bounds: &contentBounds)
        
        description.didEncounterNode(
            contentLength: contentBounds.inclusiveLength,
            userStateDeinitializer: {
                $0.assumingMemoryBound(to: UserState.self).deinitialize(count: 1)
            }
        )
        
        Content.build(description: &description)
    }
    
}

/// A group of routine bodies.

public struct RoutineBodies<each Body: RoutineBody>: RoutineBody {
    
    @inlinable
    public static func build(bounds: inout RoutineBodyDescription.Bounds) {
        repeat (each Body).build(bounds: &bounds)
    }
    
    @inlinable
    public static func build(description: inout RoutineBodyDescription) {
        repeat (each Body).build(description: &description)
    }
    
}

/// A type that provides an XML parsing routine and tracks its state.

public protocol Routine: ~Copyable {
    
    /// Tracks this routine's contextual state.
    /// You should only ever define `ctx` by assigning `context()` to this property.
    
    var ctx: RoutineContext { get }
    
    /// A type describing static metadata about this routine.
    
    associatedtype Body: RoutineBody
    
    /// Returns a `RoutineBody` built from event handlers, like `select()`.
    
    @RoutineBodyBuilder mutating func body() throws -> Body
    
}

extension Routine where Self: ~Copyable {
    
    /// Creates a `RoutineContext`.
    /// `RoutineContext`s are unique to the routine type they are created for.
    /// Sharing contexts between routines will result in undefined behavior.
    
    @inlinable
    public static func context() -> RoutineContext {
        RoutineContext(
            untargetedTrampoline: UntargetedRoutineTrampoline(for: Self.self),
            bodyDescription: RoutineBodyDescription(for: Body.self)
        )
    }
    
}

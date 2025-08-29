//
//  RoutineTrampoline.swift
//  Zemel
//
//  Created by Matt Curtis on 4/2/25.
//

/// A trampoline capable of invoking the body of a particular routine type.

@usableFromInline
struct UntargetedRoutineTrampoline {
    
    @usableFromInline
    typealias Call = (UnsafeMutableRawPointer, borrowing AnyContextualizedEvent) throws -> Void
    
    private let _call: Call
    
    @usableFromInline
    init(_call: @escaping Call) {
        self._call = _call
    }
    
    @inlinable
    init<R: Routine & ~Copyable>(for routineType: R.Type = R.self) {
        self.init {
            routinePointer, event in
            
            let routinePointer = routinePointer.assumingMemoryBound(to: routineType)
            
            try routinePointer.pointee.ctx.configuredForRun(with: event) {
                _ = try routinePointer.pointee.body()
            }
        }
    }
    
    func targeted<Result>(
        toZemel zemelPointer: UnsafeMutablePointer<Zemel>,
        andRoutine routinePointer: UnsafeMutableRawPointer,
        body: (UnsafePointer<TargetedRoutineTrampoline>) throws -> Result
    ) rethrows -> Result {
        try withUnsafePointer(to: self) {
            let targeted = TargetedRoutineTrampoline(
                untargetedTrampolinePointer: $0,
                zemelPointer: zemelPointer,
                routinePointer: routinePointer
            )
            
            return try withUnsafePointer(to: targeted) {
                try body($0)
            }
        }
    }
    
    func call(routine routinePointer: UnsafeMutableRawPointer, event: borrowing AnyContextualizedEvent) throws {
        try _call(routinePointer, event)
    }
    
}

/// A trampoline targeted to a particular routine and `Zemel` instance.

struct TargetedRoutineTrampoline {
    
    private let untargetedTrampolinePointer: UnsafePointer<UntargetedRoutineTrampoline>
    
    private let zemelPointer: UnsafeMutablePointer<Zemel>
    
    private let routinePointer: UnsafeMutableRawPointer
    
    init(untargetedTrampolinePointer: UnsafePointer<UntargetedRoutineTrampoline>, zemelPointer: UnsafeMutablePointer<Zemel>, routinePointer: UnsafeMutableRawPointer) {
        self.untargetedTrampolinePointer = untargetedTrampolinePointer
        self.zemelPointer = zemelPointer
        self.routinePointer = routinePointer
    }
    
    init(_ rawPointer: UnsafeMutableRawPointer?) {
        guard let rawPointer else {
            preconditionFailure("Unexpectedly found nil while unwrapping pointer to trampoline")
        }
        
        self = rawPointer
            .assumingMemoryBound(to: TargetedRoutineTrampoline.self)
            .pointee
    }
    
    func withZemel(body: (inout Zemel) -> Void) {
        body(&zemelPointer.pointee)
    }
    
    func callRoutine(with event: borrowing AnyContextualizedEvent) throws {
        try untargetedTrampolinePointer.pointee.call(routine: routinePointer, event: event)
    }
    
}

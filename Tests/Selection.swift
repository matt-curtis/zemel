//
//  Selection.swift
//  Zemel
//
//  Created by Matt Curtis on 6/25/25.
//

import Testing
import Zemel

@Suite("Selection")
struct SelectionTests {

    // MARK: Name Selector Tests
    
    @Suite("Name")
    struct NameSelectorTests {

        struct TestRoutine: Routine, ~Copyable {
            
            @Context var context
            
            @State var didMatch = 0

            func body() -> some RoutineBody {
                select("foo") {
                    didMatch += 1
                }
            }
            
        }

        @Test("Matches single child element by name")
        func matchesSingleChildElementByName() throws {
            var routine = TestRoutine()
            
            try parse(xml: "<foo/>", chunking: .none, using: &routine)
            
            #expect(routine.didMatch == 1)
        }

        @Test("Fails to match wrong name")
        func failsToMatchWrongName() throws {
            var routine = TestRoutine()
            
            try parse(xml: "<bar/>", chunking: .none, using: &routine)
            
            #expect(routine.didMatch == 0)
        }
    }

    // MARK: Conditional Selector Tests
    
    @Suite("Conditional")
    struct ConditionalSelectorTests {

        struct TestRoutine: Routine, ~Copyable {
            
            @Context var context
            
            @State var didMatch = 0

            mutating func body() -> some RoutineBody {
                select(try! localName() == "foo") {
                    didMatch += 1
                }
            }
            
        }

        @Test("Matches when condition is true")
        func matchesWhenConditionIsTrue() throws {
            var routine = TestRoutine()
            
            try parse(xml: "<foo/>", chunking: .none, using: &routine)
            
            #expect(routine.didMatch == 1)
        }

        @Test("Does not match when condition is false")
        func doesNotMatchWhenConditionIsFalse() throws {
            var routine = TestRoutine()
            
            try parse(xml: "<bar/>", chunking: .none, using: &routine)
            
            #expect(routine.didMatch == 0)
        }
        
    }

    // MARK: Nested Selector Tests
    
    @Suite("Nested")
    struct NestedSelectorTests {

        struct TestRoutine: Routine, ~Copyable {
            
            @Context var context
            
            @State var childMatched = 0

            func body() -> some RoutineBody {
                select("parent") {
                    select("child") {
                        childMatched += 1
                    }
                }
            }
            
        }

        @Test("Matches nested element")
        func matchesNestedElement() throws {
            var routine = TestRoutine()
            
            try parse(xml: "<parent><child/></parent>", chunking: .none, using: &routine)
            
            #expect(routine.childMatched == 1)
        }

        @Test("Does not match if parent fails")
        func doesNotMatchIfParentFails() throws {
            var routine = TestRoutine()
            
            try parse(xml: "<wrongParent><child/></wrongParent>", chunking: .none, using: &routine)
            
            #expect(routine.childMatched == 0)
        }
        
    }

    // MARK: Selector Chain Tests
    
    @Suite("Chain")
    struct SelectorChainTests {

        struct TestRoutine: Routine, ~Copyable {
            
            @Context var context
            
            @State var matched = 0

            func body() -> some RoutineBody {
                select(current.parent.child) {
                    matched += 1
                }
            }
        }

        @Test("Matches element using chain")
        func matchesElementUsingChain() throws {
            var routine = TestRoutine()
            
            try parse(xml: "<parent><child/></parent>", chunking: .none, using: &routine)
            
            #expect(routine.matched == 1)
        }

        @Test("Fails when chain does not resolve")
        func failsWhenChainDoesNotResolve() throws {
            var routine = TestRoutine()
            
            try parse(xml: "<parent><wrongChild/></parent>", chunking: .none, using: &routine)
            
            #expect(routine.matched == 0)
        }
        
    }

    // MARK: Scope Tests (child vs descendant)
    
    @Suite("Scope")
    struct ScopeTests {

        struct ChildRoutine: Routine, ~Copyable {
            
            @Context var context
            
            @State var matched = 0

            func body() -> some RoutineBody {
                select(current.parent.child) {
                    matched += 1
                }
            }
            
        }

        struct DescendantRoutine: Routine, ~Copyable {
            
            @Context var context
            
            @State var matched = 0

            func body() -> some RoutineBody {
                select("parent") {
                    select(current.descendant(true)) {
                        matched += 1
                    }
                }
            }
            
        }

        @Test("Child selector matches immediate children only")
        func childSelectorMatchesImmediateChildrenOnly() throws {
            var routine = ChildRoutine()
            
            try parse(xml: "<parent><child><grandchild/></child></parent>", chunking: .none, using: &routine)
            
            #expect(routine.matched == 1)
        }

        @Test("Descendant selector matches nested elements")
        func descendantSelectorMatchesNestedElements() throws {
            var routine = DescendantRoutine()
            
            try parse(xml: "<parent><child><grandchild/></child></parent>", chunking: .none, using: &routine)
            
            #expect(routine.matched == 2) // matches child and grandchild
        }
    }

    // MARK: Edge cases & Negative tests
    
    @Suite("Negative")
    struct NegativeTests {

        struct TestRoutine: Routine, ~Copyable {
            
            @Context var context
            
            @State var matched = 0

            mutating func body() -> some RoutineBody {
                select("nonexistent") {
                    matched += 1
                }
                
                select(current.nonexistent) {
                    matched += 1
                }
            }
            
        }

        @Test("Does not match nonexistent element")
        func doesNotMatchNonexistentElement() throws {
            var routine = TestRoutine()
            
            try parse(xml: "<foo/>", chunking: .none, using: &routine)
            
            #expect(routine.matched == 0)
        }
        
    }
    
}

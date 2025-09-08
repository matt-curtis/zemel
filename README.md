<p align="center">
    <img alt="Zemel: Swift XML parsing" src="https://github.com/user-attachments/assets/0e18093a-f333-4729-ac02-b1cc167e55ee" />
</p>

# Who is Zemel for?

If you

1. ✍️ are writing a Swift app or library
2. 📖 need to parse XML
3. 🏎️ care about doing it quickly

Zemel is for you!

# What makes Zemel different?

Zemel tries to save you time and memory.

Other XML parsing libraries will often:

1. 👎 Parse the entire XML document _before_ you can query it for information
2. 👎 Keep the entire parsed XML document in memory, taking up space

Zemel lets you:

1. ✅ **Select elements as soon as** they are parsed: **no more waiting** until the _entire_ document has been parsed before you can get what you want
2. ✅ **Stop parsing** as soon as you have the information you need, **saving you even more time**
3. ✅ **Use less memory** by not keeping the entire parsed document around in memory
4. ✅ **Parse xml in chunks**: downloading an XML file? buffering it from disk? Zemel lets you **immediately start parsing** however much you have, without reading the entire file into memory

Sound good? Great.

# How do I use Zemel?

## The basics

Parsing in Zemel is built around _Routines_. Routines are where you define your selectors.

Here's an example. Say you had the following XML of a list of people, and you want to extract the description for Beyoncé:

```xml
<people>
    <person name="Beyonce" role="president">
        Elected in the year 2028 after a contentious campaign against Taylor Swift, Knowles immediately instituted martial law, and ordered that all political opposition be drawn and quartered...
    </person>
</people>
```

To do so, you'd write a routine that looks like this:

```swift
struct BeyonceRoutine: Routine, ~Copyable {

    let ctx = context()

    var bio = ""

    func body() throws -> some Body {
        try select("people") {
            try select(presidentNamedBeyonce) {
                select(.text) { bio = try text() }
            }
        }
    }

    func presidentNamedBeyonce() -> Bool {
        name(is: "person") &&
        attribute("role", is: "president") &&
        attribute("name", is: "Beyonce")
    }

}
```

and use said routine for parsing like this:

```swift
var zemel = Zemel()
var routine = BeyonceRoutine()
let xml = "<people><person>..."

try zemel.using(&routine) {
    parse in try parse(final: true, chunk: xml)
}

print(routine.bio) // "Elected in the year 2028..."
```

That's it!

# Advanced usage

## Cancellation

Throwing an error from anywhere within a routine's `body()` will cancel parsing.

> [!IMPORTANT]
> If you want to reuse a routine for parsing _after_ you've thrown an error from its body, you'll need to call `ctx.reset()` on it.

## Selector body execution

Zemel rewrites element selector bodies. When you write:

```swift
select("persons") {
    print("parent selector!")

    select("person") {
        print("child selector!")
    }
}
```

Zemel rewrites that to:

```swift
select("persons") {
    if /* this is the first time selecting persons */ {
        print("parent selector!")
    }

    select("person") {
        if /* this is the first time selecting person */ {
            print("child selector!")
        }
    }
}
```

That way, even though Zemel executes all this code _every_ time a new piece of XML is parsed, it ensures it only calls code that is meant to be called once, once.

Zemel can't do this for every kind of statement though. There's two exceptions to keep in mind:

1. Variable declarations like `let x = ...`, `var y`, or `_ = ...` will always be executed.
2. Zemel can't rewrite throwing `try ...` statements. Instead, you should call these using `try handle { ... }`

You don't need to worry about any of these things when it comes to the bodies of text selectors, like `select(.text) { ... }`. Their bodies don't need to be rewritten at all, because text nodes can't contain other nodes to select, which means they can never have child selectors.

## Storing information about a previously selected element

All selectors (with the exception of those that select text), can store mutable state and provide it to other nested selectors in their bodies.

This can be useful for remembering information about a specific element and recalling that information in a nested selector:

```swift
try select("persons") {
    use in

    let primaryID = try use(attribute("primary")!)
    
    try select(person(withID: primaryID.value)) {
        //  found the primary person!
    }
}

func person(withID id: String) throws -> Bool {
    try localName(is: "person") &&
    attribute("id", is: .string(id))
}
```

## Working with strings

Many of Zemel's APIs (like selectors) accept strings of text as input. For performance reasons, Zemel doesn't actually accept raw Swift `String`, as `String` comes with a little bit of performance overhead. Instead, it accepts `StringSource` values.

`StringSource` is an enum that looks like this:

```swift
enum StringSource: ExpressibleByStringLiteral {
    
    case string(String)
    case staticString(StaticString)
    case pointer(UnsafePointer<UInt8>, length: Int)
    case nullTerminatedPointer(UnsafePointer<UInt8>)

}
```

`StringSource` values can be created from string literals, so when you write `select("person")` `"person"` automatically gets turned into a `StringSource`.

Most of the time you don't need to think about this, but it's worth keeping in mind in case you need to explicitly pass `String` to an API that accepts `StringSource` values, or have a UTF-8 character buffer hanging around that you want to pass directly.

## Working with names

XML involves thinking about names a bit, so let's talk about them.

In XML, elements and attributes — the two things you'll care about most often — have names. Names have two components: a namespace, and a local name (local name means "local to its namespace.")

Namespaces keep names from conflicting. So you can have names with two identical _local_ names, but so long as they're in different namespaces, they represent different names.

```xml
<fish:bass />
<music:bass />
```

Note that both of those elements have the same _local name_ (`bass`), but because they're in different namespaces (`fish` vs `music`), they have different names.

In Zemel you'll work with names through the `Name` and `Namespace` structs.

Most of the time an XML document will have one or two namespaces that all elements and attributes in the document are in, so it'll be easiest to declare your namespaces first then turn them into full names when needed by specifying a local name:

```swift
let fish: Namespace = "http://fish.com"
let music: Namespace = "http://music.com"

select(fish.bass) { // or fish["bass"]
    // ...
}

select(music.bass) { // or music["bass"]
    //  ...
}
```

You can also create names using the `Name` struct directly:

```swift
let fishName = Name(ns: "http://fish.com", localName: "bass")
let musicName = Name(ns: "http://music.com", localName: "bass")
```

Names created from string literals have _no_ namespace:

```swift
let name: Name = "joe" // Name(ns: nil, localName: "joe")
```

> [!IMPORTANT]
> When selecting **elements by `Name`**, names with `nil` namespaces match _any_ namespace. If your XML has elements from multiple namespaces, you should always specify the exact namespace the element you're trying to select is in.

## Simple selectors

Selecting elements happens through overloads of the `select()` method. Element selectors can have other selectors nested within them.

### Selecting children or descendants by name

```swift
func select(Name, ...) // selects children
func select(descendant: Name, ...) // selects descendants
```

### Selecting children or descendants by condition

```swift
func select(@autoclosure () -> Bool, ...) // selects children
func select(descendant: @autoclosure () -> Bool, ...) // selects descendants
```

### Selecting descendant text

```swift
func select(.text, ...)
```

Read [more about selecting text](#selecting-text).

## Selector chains

You can combine multiple selectors that would otherwise have to be nested into one single selector. For example, instead of writing:

```swift
select("persons") {
    select("person") {
        //  ...
    }
}
```

you can write:

```swift
select(current.persons.person) {
    //  ...
}
```

which would let you select each person from this XML:

```xml
<persons>
    <person>Joe Smith</person>
    <person>Maggie Rath</person>
    <person>Aly Tryst</person>
</persons>
```

You can also write this selector more explicitly:

```swift
select(current.child("persons").child("person")) {
    //  ...
}
```

Just like with the `select()` methods, `current` has several methods on it (in addition to the dynamic member lookup demonstrated above) that mirror `select()` and enable selecting text and elements by name or condition:

```swift
current.child(Name)
current.descendant(Name)
current.child(@autoclosure () -> Bool)
current.descendant(@autoclosure () -> Bool)
current.text()
```

## Selector conditions

Sometimes you'll want to select elements based on a more complex series of conditions than just its name. It's pretty common, for example, to want to select an element based on its name and some attribute it has. The conditional variations of selectors are meant for just this:

```swift
func myCondition() throws -> Bool {
    try name(is: "person") && attribute("age", is: "65")
}

select(myCondition()) {
    //  ... selected person
}
```

You can technically write any condition you want, even based on information not derived from the current element.

## Selecting text

You can select descendant text using either `select(.text)` or `select(current...text())`, and calling `text()` to get the selected text node as a `String`.

Keep in mind the text selector fires for each text node in an element, so if for the following XML:

```xml
<persons>
    <person>
        <role>Developer</role>
        <name>
            <first>Matt</first>
            <last>Curtis</last>
        </name>
    </person>
</person>
```

you wrote:

```swift
select(current.persons.text()) {
    print(try text())
}
```

you'd see printed:

```swift
"Developer"
"Matt"
"Curtis"
```

This means if you want to combine all the text within an element into one string, you'll need to do so directly:

```swift
var allText = ""

func body() {
    select(current.persons.text()) {
        allText += try text()
    }
}
```

## Information about the current element

There are a number of methods for getting information about the current element. These methods all throw if they are called when the current node is not an element.

There's two flavors of information you can get about an element. The first is around its name:

```swift
func name() -> Name
func name(is: StringSource) throws -> Bool

func localName() throws -> String
func localName(is: StringSource) throws -> Bool
```

and the second around its attributes.

```swift
func attribute(exists: Name) throws -> Bool
func attribute(Name) throws -> String?
func attribute(Name, is: StringSource) throws -> Bool
func withAttributes(body: (borrowing AttributeIterator) throws -> Void) throws
```

That last method, `withAttributes()`, lets you iterate over the attributes on an element:

```swift
try withAttributes {
    iterator in
    
    repeat {
        print(iterator.name(), iterator.value())
    }
    while iterator.next()
}
```

## Information about the current text node

These methods throw if the current node isn't a text node.

```swift
func text() -> String
func withText(body: (borrowing UnsafeBufferPointer<UInt8>) throws -> Void) throws
```

`withText()` calls its body with the text of the current text node as a UTF-8 string buffer, which can be useful when you need to parse the contents of a text node quickly and without incurring some of the overhead of `String`.
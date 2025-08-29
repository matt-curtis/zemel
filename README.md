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

# To be continued...

> [!WARNING]
> This README is a work in progress. More documentation is coming soon!
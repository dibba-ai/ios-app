import Testing
@testable import Intents

@Suite("String.nilIfEmpty")
struct StringNilIfEmptyTests {
    @Test("Empty string returns nil")
    func empty() {
        #expect("".nilIfEmpty == nil)
    }

    @Test("Whitespace-only returns nil")
    func whitespace() {
        #expect("   ".nilIfEmpty == nil)
        #expect("\n\t".nilIfEmpty == nil)
    }

    @Test("Trimmed value returned")
    func trimmed() {
        #expect("  hello  ".nilIfEmpty == "hello")
        #expect("foo".nilIfEmpty == "foo")
    }
}

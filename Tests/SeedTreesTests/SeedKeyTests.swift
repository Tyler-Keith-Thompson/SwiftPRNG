// Each test is self-contained.

import Foundation
import SeedTrees
import SwiftPRNGTestSupport
import Testing

@Suite("SeedKey")
struct SeedKeyTests {
    @Test("A string literal is a name and an integer literal an index")
    func literals() {
        let name: SeedKey = "agent"
        let index: SeedKey = 7

        #expect(name == .name("agent"))
        #expect(index == .index(7))
        #expect(name != "7")
        #expect(SeedKey.name("7") != SeedKey.index(7))
    }

    @Test("The description is the name, or the index written out")
    func description() {
        #expect(SeedKey.name("agent").description == "agent")
        #expect(SeedKey.index(7).description == "7")
        #expect(SeedKey.index(-1).description == "-1")
        #expect(SeedKey.name("").description == "")
    }

    @Test("Indices sort before names, and each kind in its own order", .tags(.conformance))
    func ordering() {
        let keys: [SeedKey] = ["b", 3, "a", -2, 0]
        let expected: [SeedKey] = [-2, 0, 3, "a", "b"]

        #expect(keys.sorted() == expected)
        #expect(!(SeedKey.name("a") < .index(100)))
    }

    @Test("An index encodes as a number and a name as a string, and both decode", .tags(.conformance))
    func codable() throws {
        let path: SeedPath = ["agent", 7, "7", -1, ""]
        let expectedJSON = "[\"agent\",7,\"7\",-1,\"\"]"

        let data = try JSONEncoder().encode(path)
        let decoded = try JSONDecoder().decode(SeedPath.self, from: data)

        #expect(String(decoding: data, as: UTF8.self) == expectedJSON)
        #expect(decoded == path)
    }

    @Test("An Int is an index key and a String a name key, so variables step through a tree")
    func convertible() {
        let index = 7
        let name = "agent"
        let tree = SeedTree(42)

        #expect(index.seedKey == .index(7))
        #expect(name.seedKey == .name("agent"))
        #expect(SeedKey.index(3).seedKey == .index(3))
        #expect(tree[name, index] == tree["agent", 7])
        #expect(tree[name, index, "delay"] == tree["agent", 7, "delay"])
        #expect((0 ..< 3).map { tree["agent", $0].seed } == [tree["agent", 0].seed, tree["agent", 1].seed, tree["agent", 2].seed])
        #expect(tree[SeedKey.name("agent"), 7] == tree["agent", 7])
    }

    @Test("Equal keys hash equally", .tags(.conformance))
    func hashing() {
        #expect(SeedKey.name("a").hashValue == SeedKey("a").hashValue)
        #expect(Set<SeedKey>(["a", 1, "a", 1]).count == 2)
    }
}

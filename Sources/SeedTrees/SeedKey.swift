import Generators

/// One step of a path through a ``SeedTree``: a name or an index.
///
/// Keys are written as literals: `tree["agent", 7]` steps through `.name("agent")` then
/// `.index(7)`. A name and the index it spells are different keys, so `tree["7"]` and `tree[7]`
/// are different nodes.
@frozen
public enum SeedKey: Hashable, Sendable, Comparable, Codable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, CustomStringConvertible {
    /// A named child, such as a decision or a kind of entity.
    case name(String)
    /// A numbered child, such as one entity among many.
    case index(Int)

    @inlinable
    public init(stringLiteral value: String) { self = .name(value) }

    @inlinable
    public init(integerLiteral value: Int) { self = .index(value) }

    /// The name, or the index written out.
    public var description: String {
        switch self {
        case let .name(name): name
        case let .index(index): String(index)
        }
    }

    /// Indices before names; each kind in its natural order.
    public static func < (lhs: SeedKey, rhs: SeedKey) -> Bool {
        switch (lhs, rhs) {
        case let (.index(left), .index(right)): left < right
        case let (.name(left), .name(right)): left < right
        case (.index, .name): true
        case (.name, .index): false
        }
    }

    /// An index decodes from a number and a name from a string.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let index = try? container.decode(Int.self) {
            self = .index(index)
        } else {
            self = .name(try container.decode(String.self))
        }
    }

    /// An index encodes as a number and a name as a string.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .name(name): try container.encode(name)
        case let .index(index): try container.encode(index)
        }
    }

    /// A 64-bit value standing for the key, the same on every platform and in every process,
    /// unlike `Hasher`'s. Names are hashed with FNV-1a; both kinds are then mixed with SplitMix64.
    @usableFromInline
    var mixingValue: UInt64 {
        switch self {
        case let .index(index):
            // The constant separates index 0 from the name hash's starting value.
            return SeedTree.derive(UInt64(bitPattern: Int64(index)) ^ 0x6A09_E667_F3BC_C908)
        case let .name(name):
            var hash: UInt64 = 0xCBF2_9CE4_8422_2325
            for byte in name.utf8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
            return SeedTree.derive(hash)
        }
    }
}

/// The keys from a seed tree's root to one of its nodes.
public typealias SeedPath = [SeedKey]

/// A value that names a step through a ``SeedTree``: a ``SeedKey``, an `Int` (an index) or a
/// `String` (a name), so `tree["agent", index]` takes variables as well as literals.
public protocol SeedKeyConvertible {
    /// The key this value names.
    var seedKey: SeedKey { get }
}

extension SeedKey: SeedKeyConvertible {
    @inlinable
    public var seedKey: SeedKey { self }
}

extension Int: SeedKeyConvertible {
    @inlinable
    public var seedKey: SeedKey { .index(self) }
}

extension String: SeedKeyConvertible {
    @inlinable
    public var seedKey: SeedKey { .name(self) }
}

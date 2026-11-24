/// Shuffles and element picks whose algorithm is fixed here, so a seeded generator reproduces them
/// on every platform and in every Swift release, where the standard library's
/// `shuffle(using:)`, `shuffled(using:)` and `randomElement(using:)` promise only a correct
/// distribution.
extension RandomNumberGenerator {
    /// Shuffles `collection` in place, every permutation equally likely.
    ///
    /// Fisher–Yates from the last offset down: for each offset `i` from `count - 1` down to 1, the
    /// element at `i` swaps with the element at ``integer(in:)-(ClosedRange<Int>)`` over `0 ... i`.
    /// Offsets count from `startIndex`, so a slice shuffles as the array of its elements would.
    /// The result is the same on every platform and in every Swift release.
    ///
    /// - Parameter collection: The elements to shuffle.
    /// - Complexity: O(*n*), where *n* is the collection's count: *n* − 1 integer draws, each one
    ///   draw from the generator and another with probability below 2⁻⁶⁴ × (*i* + 1). An empty or
    ///   one-element collection takes no draw.
    @inlinable
    public mutating func shuffle(_ collection: inout some MutableCollection & RandomAccessCollection) {
        var offset = collection.count - 1
        guard offset > 0 else { return }
        var index = collection.index(before: collection.endIndex)
        while offset > 0 {
            let other = collection.index(collection.startIndex, offsetBy: integer(in: 0 ... offset))
            collection.swapAt(index, other)
            collection.formIndex(before: &index)
            offset -= 1
        }
    }

    /// The elements of `sequence` in a random order, every permutation equally likely.
    ///
    /// The array of the elements, shuffled by ``shuffle(_:)``, so it takes the same draws and
    /// gives the same order. The result is the same on every platform and in every Swift release.
    ///
    /// - Parameter sequence: The elements to shuffle; a finite sequence.
    /// - Returns: A new array holding the elements of `sequence`.
    /// - Complexity: O(*n*), where *n* is the sequence's length: *n* − 1 integer draws, none for an
    ///   empty or one-element sequence.
    @inlinable
    public mutating func shuffled<Element>(_ sequence: some Sequence<Element>) -> [Element] {
        var elements = Array(sequence)
        shuffle(&elements)
        return elements
    }

    /// A random element of `collection`, each equally likely, or `nil` when it is empty.
    ///
    /// The element at the offset one ``integer(in:)-(Range<Int>)`` draw over `0 ..< count` gives,
    /// counted from `startIndex`. The result is the same on every platform and in every Swift
    /// release.
    ///
    /// - Parameter collection: The elements to choose from.
    /// - Returns: The chosen element, or `nil` for an empty collection, which takes no draw.
    /// - Complexity: One integer draw, which is one draw from the generator and another with
    ///   probability below 2⁻⁶⁴ × *n*. O(1) for a `RandomAccessCollection`, otherwise O(*n*), where
    ///   *n* is the collection's count.
    @inlinable
    public mutating func element<Element>(in collection: some Collection<Element>) -> Element? {
        guard !collection.isEmpty else { return nil }
        return collection[collection.index(collection.startIndex, offsetBy: integer(in: 0 ..< collection.count))]
    }
}

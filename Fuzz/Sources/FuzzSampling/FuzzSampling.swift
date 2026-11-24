// The draws against a model of their bounds: every integer lands in its range, every uniform in
// its interval, the checked spellings throw exactly when the plain ones would trap, and the plain
// and checked spellings agree on the same generator state. Shuffles and element picks against
// Fisher-Yates and the offset draw written out: the same order, the same element, and the
// generator left where the model leaves it.

import FuzzSupport
import Generators
import Sampling

@main
enum FuzzSampling {
    static func main() { runFuzzer(fuzz) }

    // Bounds near the edges of Int and around zero, where arithmetic can wrap.
    static let anchors: [Int] = [.min, .min + 1, -1_000_000, -3, -1, 0, 1, 2, 3, 1_000_000, .max - 1, .max]

    static func fuzz(_ input: inout FuzzInput) {
        var generator = Xoshiro256StarStar(seed: UInt64(input.byte()) | UInt64(input.byte()) << 8)
        while !input.isEmpty {
            switch input.int(below: 6) {
            case 0:
                let lower = anchors[input.int(below: anchors.count)] &+ (Int(input.byte()) - 128)
                let upper = anchors[input.int(below: anchors.count)] &+ (Int(input.byte()) - 128)
                // A Range needs lower <= upper; the empty range lower ..< lower is the checked case.
                let range = min(lower, upper) ..< max(lower, upper)
                var checked = generator
                let result = Result { () throws(EmptyRange) in try checked.integer(checkedIn: range) }
                if !range.isEmpty {
                    let value = generator.integer(in: range)
                    check(range.contains(value), "integer \(value) outside \(range)")
                    check((try? result.get()) == value, "checked integer disagrees with plain")
                    check(checked == generator, "checked integer consumed a different number of draws")
                } else {
                    check((try? result.get()) == nil, "checked integer did not throw for \(range)")
                }
            case 1:
                let first = anchors[input.int(below: anchors.count)] &+ (Int(input.byte()) - 128)
                let second = anchors[input.int(below: anchors.count)] &+ (Int(input.byte()) - 128)
                let range = min(first, second) ... max(first, second)
                let value = generator.integer(in: range)
                check(range.contains(value), "integer \(value) outside \(range)")
            case 2:
                let lower = Double(Int(input.byte()) - 128) * [1, 1e-9, 1e9, 1e300][input.int(below: 4)]
                let width = Double(input.byte()) * [1, 1e-12, 1e6, 1e300][input.int(below: 4)]
                let upper = lower + width
                var checked = generator
                let result = Result { () throws(InvalidInterval) in try checked.uniform(checkedIn: lower ..< upper) }
                if lower < upper, upper.isFinite {
                    let value = generator.uniform(in: lower ..< upper)
                    check(value >= lower && value < upper, "uniform \(value) outside \(lower) ..< \(upper)")
                    check((try? result.get()) == value, "checked uniform disagrees with plain")
                } else {
                    check((try? result.get()) == nil, "checked uniform did not throw for \(lower) ..< \(upper)")
                }
            case 4:
                // Few distinct values, so ties are common and a lost or duplicated element shows.
                var elements = (0 ..< input.int(below: 40)).map { _ in input.int(below: 4) }
                let lower = input.int(below: elements.count + 1)
                let upper = lower + input.int(below: elements.count - lower + 1)
                var expected = elements
                var reference = generator
                for i in stride(from: upper - lower - 1, to: 0, by: -1) {
                    expected.swapAt(lower + i, lower + reference.integer(in: 0 ... i))
                }
                let snapshot = elements
                var copying = generator
                let copied = copying.shuffled(elements[lower ..< upper])
                generator.shuffle(&elements[lower ..< upper])
                check(elements == expected, "shuffle of \(lower) ..< \(upper) disagrees with Fisher-Yates")
                check(generator == reference, "shuffle consumed a different number of draws")
                check(copied == Array(expected[lower ..< upper]), "shuffled disagrees with shuffle")
                check(copying == generator, "shuffled consumed a different number of draws")
                check(snapshot.sorted() == elements.sorted(), "shuffle lost or duplicated an element")
            case 5:
                let elements = (0 ..< input.int(below: 40)).map { _ in input.int(below: 4) }
                var reference = generator
                let expected = elements.isEmpty ? nil : elements[reference.integer(in: 0 ..< elements.count)]
                var sliced = generator
                var sliceReference = generator
                check(generator.element(in: elements) == expected, "element disagrees with the offset draw")
                check(generator == reference, "element consumed a different number of draws")
                let start = elements.isEmpty ? 0 : input.int(below: elements.count)
                let expectedFromSlice = start == elements.count ? nil : elements[start + sliceReference.integer(in: 0 ..< elements.count - start)]
                check(sliced.element(in: elements[start...]) == expectedFromSlice, "element of a slice disagrees with the offset draw")
                check(sliced == sliceReference, "element of a slice consumed a different number of draws")
            default:
                let probability = Double(Int(input.byte()) - 64) / 128
                var checked = generator
                let result = Result { () throws(InvalidProbability) in try checked.bernoulli(checked: probability) }
                if probability >= 0, probability <= 1 {
                    var reference = generator
                    let expected = reference.uniform() < probability
                    check(generator.bernoulli(probability) == expected, "bernoulli disagrees with the comparison")
                    check((try? result.get()) == expected, "checked bernoulli disagrees with plain")
                } else {
                    check((try? result.get()) == nil, "checked bernoulli did not throw for \(probability)")
                }
            }
        }
    }
}

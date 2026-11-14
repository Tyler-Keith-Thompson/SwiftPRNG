// The generators against their own laws under any sequence of operations: a copy taken earlier
// is unaffected by later draws; jumped() leaves what jump() leaves; and two generators that have
// stepped through the same operations agree, and hash alike.

import FuzzSupport
import Generators

@main
enum FuzzGenerators {
    static func main() { runFuzzer(fuzz) }

    static func fuzz(_ input: inout FuzzInput) {
        let seed = UInt64(input.byte()) | UInt64(input.byte()) << 8 | UInt64(input.byte()) << 56
        var xoroshiro = Xoroshiro128Plus(seed: seed)
        var xoshiro = Xoshiro256StarStar(seed: seed)
        var splitMix = SplitMix64(seed: seed)
        var twin = (xoroshiro, xoshiro, splitMix)
        var snapshot: (Xoroshiro128Plus, Xoshiro256StarStar, SplitMix64, UInt64, UInt64, UInt64)?

        while !input.isEmpty {
            switch input.int(below: 6) {
            case 0:
                let draws = input.int(in: 1 ... 8)
                for _ in 0 ..< draws {
                    check(xoroshiro.next() == twin.0.next(), "twin xoroshiro drifted")
                    check(xoshiro.next() == twin.1.next(), "twin xoshiro drifted")
                    check(splitMix.next() == twin.2.next(), "twin splitmix drifted")
                }
            case 1:
                let jumped = (xoroshiro.jumped(), xoshiro.jumped())
                xoroshiro.jump()
                xoshiro.jump()
                twin.0.jump()
                twin.1.jump()
                check(jumped.0 == xoroshiro && jumped.1 == xoshiro, "jumped() differs from jump()")
            case 2:
                let jumped = (xoroshiro.longJumped(), xoshiro.longJumped())
                xoroshiro.longJump()
                xoshiro.longJump()
                twin.0.longJump()
                twin.1.longJump()
                check(jumped.0 == xoroshiro && jumped.1 == xoshiro, "longJumped() differs from longJump()")
            case 3:
                var copies = (xoroshiro, xoshiro, splitMix)
                snapshot = (xoroshiro, xoshiro, splitMix, copies.0.next(), copies.1.next(), copies.2.next())
            case 4:
                let copy = xoroshiro
                check(copy.jumped().jumped() == xoroshiro.longJumped() || copy.jumped() != xoroshiro.longJumped(), "a jump equals a long jump")
            default:
                check(xoroshiro.hashValue == twin.0.hashValue && xoshiro.hashValue == twin.1.hashValue, "equal generators hash differently")
            }
            check(xoroshiro == twin.0 && xoshiro == twin.1 && splitMix == twin.2, "twins differ after the same operations")
            if let (copy0, copy1, copy2, first0, first1, first2) = snapshot {
                var replay = (copy0, copy1, copy2)
                check(replay.0.next() == first0 && replay.1.next() == first1 && replay.2.next() == first2, "a copy taken earlier changed")
            }
        }
    }
}

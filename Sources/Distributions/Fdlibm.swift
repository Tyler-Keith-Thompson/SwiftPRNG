// Ported from FreeBSD's msun (lib/msun/src/e_log.c, s_log1p.c, e_exp.c, k_sin.c, k_cos.c) and
// musl's scalbn, by way of the Rust libm crate:
//
// ====================================================
// Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
//
// Developed at SunSoft, a Sun Microsystems, Inc. business.
// Permission to use, copy, modify, and distribute this
// software is freely granted, provided that this notice
// is preserved.
// ====================================================
//
// Why a port rather than Foundation's `log` and `exp`: each platform's libm (Darwin's, glibc's,
// WASI's) rounds differently in the last bit, and a sample that differs by one ulp can flip a
// comparison and change everything after it. These use only IEEE 754 arithmetic, which Swift never
// contracts into fused operations, so they return the same bits everywhere. Each stays within
// one ulp of the true value. Constants are their bit patterns, the values fdlibm states in hex.
// swift-numerics' RealModule was rejected: it forwards to the platform's libm. The functions stay
// out of line (`@usableFromInline`, not `@inlinable`): inlined into each sampler they measured
// slower, from the larger loop bodies.

/// Natural logarithm, exponential and cosine that return the same bits on every platform.
@usableFromInline
package enum Fdlibm {
    @usableFromInline static let ln2Hi = Double(bitPattern: 0x3FE6_2E42_FEE0_0000)
    @usableFromInline static let ln2Lo = Double(bitPattern: 0x3DEA_39EF_3579_3C76)
    @usableFromInline static let lg1 = Double(bitPattern: 0x3FE5_5555_5555_5593)
    @usableFromInline static let lg2 = Double(bitPattern: 0x3FD9_9999_9997_FA04)
    @usableFromInline static let lg3 = Double(bitPattern: 0x3FD2_4924_9422_9359)
    @usableFromInline static let lg4 = Double(bitPattern: 0x3FCC_71C5_1D8E_78AF)
    @usableFromInline static let lg5 = Double(bitPattern: 0x3FC7_4664_96CB_03DE)
    @usableFromInline static let lg6 = Double(bitPattern: 0x3FC3_9A09_D078_C69F)
    @usableFromInline static let lg7 = Double(bitPattern: 0x3FC2_F112_DF3E_5244)

    /// The natural logarithm of `x`: −∞ at zero, NaN below it.
    @usableFromInline
    package static func log(_ x: Double) -> Double {
        var x = x
        var bits = x.bitPattern
        var high = UInt32(truncatingIfNeeded: bits >> 32)
        var k: Int32 = 0
        if high < 0x0010_0000 || high >> 31 != 0 {
            if bits << 1 == 0 { return -.infinity }
            if high >> 31 != 0 { return .nan }
            // A subnormal: scale it into the normal range first.
            k -= 54
            x *= 0x1p54
            bits = x.bitPattern
            high = UInt32(truncatingIfNeeded: bits >> 32)
        } else if high >= 0x7FF0_0000 {
            return x
        } else if high == 0x3FF0_0000, bits << 32 == 0 {
            return 0
        }
        // x = 2^k · (1 + f) with 1 + f in [√2/2, √2).
        high &+= 0x3FF0_0000 - 0x3FE6_A09E
        k += Int32(high >> 20) - 0x3FF
        high = (high & 0x000F_FFFF) &+ 0x3FE6_A09E
        bits = UInt64(high) << 32 | (bits & 0xFFFF_FFFF)
        let f = Double(bitPattern: bits) - 1
        let hfsq = 0.5 * f * f
        let s = f / (2 + f)
        let z = s * s
        let w = z * z
        let t1 = w * (lg2 + w * (lg4 + w * lg6))
        let t2 = z * (lg1 + w * (lg3 + w * (lg5 + w * lg7)))
        let r = t2 + t1
        let dk = Double(k)
        return s * (hfsq + r) + dk * ln2Lo - hfsq + f + dk * ln2Hi
    }

    /// The natural logarithm of 1 + `x`, accurate for `x` near zero: −∞ at −1, NaN below it.
    @usableFromInline
    package static func log1p(_ x: Double) -> Double {
        let high = UInt32(truncatingIfNeeded: x.bitPattern >> 32)
        var k: Int32 = 1
        var f = 0.0
        var c = 0.0
        if high < 0x3FDA_827A || high >> 31 != 0 {
            if high >= 0xBFF0_0000 {
                return x == -1 ? -.infinity : .nan
            }
            if high << 1 < 0x3CA0_0000 << 1 {
                return x // |x| < 2⁻⁵³
            }
            if high <= 0xBFD2_BEC4 {
                // √2/2 ≤ 1 + x < √2: f = x exactly.
                k = 0
                f = x
            }
        } else if high >= 0x7FF0_0000 {
            return x
        }
        if k > 0 {
            var bits = (1 + x).bitPattern
            var highU = UInt32(truncatingIfNeeded: bits >> 32)
            highU &+= 0x3FF0_0000 - 0x3FE6_A09E
            k = Int32(highU >> 20) - 0x3FF
            // The rounding error of 1 + x, carried as a correction c/u.
            if k < 54 {
                let u = Double(bitPattern: bits)
                c = k >= 2 ? 1 - (u - x) : x - (u - 1)
                c /= u
            }
            highU = (highU & 0x000F_FFFF) &+ 0x3FE6_A09E
            bits = UInt64(highU) << 32 | (bits & 0xFFFF_FFFF)
            f = Double(bitPattern: bits) - 1
        }
        let hfsq = 0.5 * f * f
        let s = f / (2 + f)
        let z = s * s
        let w = z * z
        let t1 = w * (lg2 + w * (lg4 + w * lg6))
        let t2 = z * (lg1 + w * (lg3 + w * (lg5 + w * lg7)))
        let r = t2 + t1
        let dk = Double(k)
        return s * (hfsq + r) + (dk * ln2Lo + c) - hfsq + f + dk * ln2Hi
    }

    @usableFromInline static let invLn2 = Double(bitPattern: 0x3FF7_1547_652B_82FE)
    @usableFromInline static let p1 = Double(bitPattern: 0x3FC5_5555_5555_553E)
    @usableFromInline static let p2 = Double(bitPattern: 0xBF66_C16C_16BE_BD93)
    @usableFromInline static let p3 = Double(bitPattern: 0x3F11_566A_AF25_DE2C)
    @usableFromInline static let p4 = Double(bitPattern: 0xBEBB_BD41_C5D2_6BF1)
    @usableFromInline static let p5 = Double(bitPattern: 0x3E66_3769_72BE_A4D0)

    /// e raised to `x`: +∞ above about 709.78, zero below about −745.13.
    @usableFromInline
    package static func exp(_ x: Double) -> Double {
        var x = x
        let word = UInt32(truncatingIfNeeded: x.bitPattern >> 32)
        let sign = Int32(word >> 31)
        let high = word & 0x7FFF_FFFF
        if high >= 0x4086_232B {
            if x.isNaN { return x }
            if x > 709.782712893383973096 { return x * 0x1p1023 }
            if x < -745.13321910194110842 { return 0 }
        }
        // x = k·ln2 + r with |r| ≤ ln2 / 2, r held as hi − lo.
        let k: Int32
        let hi: Double
        let lo: Double
        if high > 0x3FD6_2E42 {
            if high >= 0x3FF0_A2B2 {
                k = Int32(invLn2 * x + (sign == 0 ? 0.5 : -0.5))
            } else {
                k = 1 - sign - sign
            }
            hi = x - Double(k) * ln2Hi
            lo = Double(k) * ln2Lo
            x = hi - lo
        } else if high > 0x3E30_0000 {
            k = 0
            hi = x
            lo = 0
        } else {
            return 1 + x
        }
        let xx = x * x
        let c = x - xx * (p1 + xx * (p2 + xx * (p3 + xx * (p4 + xx * p5))))
        let y = 1 + (x * c / (2 - c) - lo + hi)
        return k == 0 ? y : scalbn(y, k)
    }

    /// `x` × 2ⁿ, rounded once.
    @usableFromInline
    static func scalbn(_ x: Double, _ n: Int32) -> Double {
        var y = x
        var n = n
        if n > 1023 {
            y *= 0x1p1023
            n -= 1023
            if n > 1023 {
                y *= 0x1p1023
                n -= 1023
                if n > 1023 { n = 1023 }
            }
        } else if n < -1022 {
            // Scaling to 2⁻⁹⁶⁹ first keeps the result normal until the last multiply, so a
            // subnormal result is rounded once.
            y *= 0x1p-969
            n += 1022 - 53
            if n < -1022 {
                y *= 0x1p-969
                n += 1022 - 53
                if n < -1022 { n = -1022 }
            }
        }
        return y * Double(bitPattern: UInt64(0x3FF + n) << 52)
    }

    @usableFromInline static let c1 = Double(bitPattern: 0x3FA5_5555_5555_554C)
    @usableFromInline static let c2 = Double(bitPattern: 0xBF56_C16C_16C1_5177)
    @usableFromInline static let c3 = Double(bitPattern: 0x3EFA_01A0_19CB_1590)
    @usableFromInline static let c4 = Double(bitPattern: 0xBE92_7E4F_809C_52AD)
    @usableFromInline static let c5 = Double(bitPattern: 0x3E21_EE9E_BDB4_B1C4)
    @usableFromInline static let c6 = Double(bitPattern: 0xBDA8_FAE9_BE88_38D4)
    @usableFromInline static let s1 = Double(bitPattern: 0xBFC5_5555_5555_5549)
    @usableFromInline static let s2 = Double(bitPattern: 0x3F81_1111_1110_F8A6)
    @usableFromInline static let s3 = Double(bitPattern: 0xBF2A_01A0_19C1_61D5)
    @usableFromInline static let s4 = Double(bitPattern: 0x3EC7_1DE3_57B1_FE7D)
    @usableFromInline static let s5 = Double(bitPattern: 0xBE5A_E5E6_8A2B_9CEB)
    @usableFromInline static let s6 = Double(bitPattern: 0x3DE5_D93A_5ACF_D57C)
    @usableFromInline static let halfPi = Double(bitPattern: 0x3FF9_21FB_5444_2D18)

    /// cos(π`x`), for |`x`| below 2⁵⁰.
    ///
    /// The reduction to a quarter turn is exact, because `x` counts half turns: 2`x` is split into
    /// a whole number of quarter turns and a remainder in [−½, ½], both exact.
    @usableFromInline
    package static func cosPi(_ x: Double) -> Double {
        let quarters = 2 * x
        let whole = quarters.rounded(.toNearestOrEven)
        let y = (quarters - whole) * halfPi
        switch Int64(whole) & 3 {
        case 0: return cosKernel(y)
        case 1: return -sinKernel(y)
        case 2: return -cosKernel(y)
        default: return sinKernel(y)
        }
    }

    /// cos(`x`) for |`x`| ≤ π/4.
    @usableFromInline
    static func cosKernel(_ x: Double) -> Double {
        let z = x * x
        let w = z * z
        let r = z * (c1 + z * (c2 + z * c3)) + w * w * (c4 + z * (c5 + z * c6))
        let hz = 0.5 * z
        let v = 1 - hz
        return v + (((1 - v) - hz) + z * r)
    }

    /// sin(`x`) for |`x`| ≤ π/4.
    @usableFromInline
    static func sinKernel(_ x: Double) -> Double {
        let z = x * x
        let w = z * z
        let r = s2 + z * (s3 + z * s4) + z * w * (s5 + z * s6)
        let v = z * x
        return x + v * (s1 + z * r)
    }
}

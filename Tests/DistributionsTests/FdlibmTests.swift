// Fdlibm's public log, log1p and exp pinned bit for bit. The expected bit patterns come from the
// Python reference in scripts/differential_distributions.py (its `log`, `log1p` and `exp` on each
// input's bits), so a change to any of them, or to the port, shows here on every platform.

import Distributions
import Testing

@Suite("Distributions: Fdlibm")
struct FdlibmTests {
    @Test("log returns fdlibm's bits on 1, subnormals, the extreme normals and values in (0, 1]", arguments: [
        // 1
        (0x3FF0_0000_0000_0000, 0x0000_0000_0000_0000),
        // Subnormals: the least nonzero magnitude, the greatest subnormal and one between.
        (0x0000_0000_0000_0001, 0xC087_4385_446D_71C3),
        (0x000F_FFFF_FFFF_FFFF, 0xC086_232B_DD7A_BCD2),
        (0x0000_0000_1234_5678, 0xC086_A739_15E9_844A),
        // The least normal and greatest finite magnitudes.
        (0x0010_0000_0000_0000, 0xC086_232B_DD7A_BCD2),
        (0x7FEF_FFFF_FFFF_FFFF, 0x4086_2E42_FEFA_39EF),
        // Values in (0, 1]: 1e-300, 0.1, 0.5, 0.75, 0.9999 and the greatest below 1.
        (0x01A5_6E1F_C2F8_F359, 0xC085_9634_47F8_7FB5),
        (0x3FB9_9999_9999_999A, 0xC002_6BB1_BBB5_5515),
        (0x3FE0_0000_0000_0000, 0xBFE6_2E42_FEFA_39EF),
        (0x3FE8_0000_0000_0000, 0xBFD2_6962_1134_DB92),
        (0x3FEF_FF2E_48E8_A71E, 0xBF1A_3738_D2CF_1CC2),
        (0x3FEF_FFFF_FFFF_FFFF, 0xBCA0_0000_0000_0000),
    ] as [(UInt64, UInt64)])
    func logBits(input: UInt64, expected: UInt64) {
        let x = Double(bitPattern: input)

        let actual = Fdlibm.log(x).bitPattern

        #expect(actual == expected)
    }

    @Test("log1p returns fdlibm's bits near zero, near −1 and far from both", arguments: [
        (0x3FE0_0000_0000_0000, 0x3FD9_F323_ECBF_984C), // 0.5
        (0xBFE0_0000_0000_0000, 0xBFE6_2E42_FEFA_39EF), // −0.5
        (0x3DDB_7CDF_D9D7_BDBB, 0x3DDB_7CDF_D9D1_D693), // 1e-10
        (0x3FFE_1EAC_5F2F_D003, 0x3FF0_F03F_32A1_E599), // 1.8824886053307643
        (0x7E37_E43C_8800_759C, 0x4085_9634_47F8_7FB5), // 1e300
        (0xBFEF_FFFF_CA50_1ACB, 0xC030_1E3B_8440_ED2F), // −0.9999999
    ] as [(UInt64, UInt64)])
    func log1pBits(input: UInt64, expected: UInt64) {
        let x = Double(bitPattern: input)

        let actual = Fdlibm.log1p(x).bitPattern

        #expect(actual == expected)
    }

    @Test("exp returns fdlibm's bits near zero, near overflow and in the subnormal range", arguments: [
        (0x3FF0_0000_0000_0000, 0x4005_BF0A_8B14_576A), // 1
        (0xBFF0_0000_0000_0000, 0x3FD7_8B56_362C_EF38), // −1
        (0x3FE0_0000_0000_0000, 0x3FFA_6129_8E1E_069C), // 0.5
        (0x3DDB_7CDF_D9D7_BDBB, 0x3FF0_0000_0006_DF38), // 1e-10
        (0x4085_E000_0000_0000, 0x7F0D_945D_F4F8_EC8E), // 700
        (0xC086_2400_0000_0000, 0x000E_6CF6_D088_97AC), // −708.5
        (0xC087_2000_0000_0000, 0x0000_0000_0000_0055), // −740
    ] as [(UInt64, UInt64)])
    func expBits(input: UInt64, expected: UInt64) {
        let x = Double(bitPattern: input)

        let actual = Fdlibm.exp(x).bitPattern

        #expect(actual == expected)
    }

    @Test("log, log1p and exp give the special values their documentation states")
    func specialValues() {
        let negativeInfinity = -Double.infinity
        let positiveZero = 0.0
        let negativeZero = -0.0
        let one = 1.0

        #expect(Fdlibm.log(1).bitPattern == positiveZero.bitPattern)
        #expect(Fdlibm.log(positiveZero) == negativeInfinity)
        #expect(Fdlibm.log(negativeZero) == negativeInfinity)
        #expect(Fdlibm.log(-Double.leastNonzeroMagnitude).isNaN)
        #expect(Fdlibm.log(negativeInfinity).isNaN)
        #expect(Fdlibm.log(.nan).isNaN)
        #expect(Fdlibm.log(-Double.nan).isNaN)
        #expect(Fdlibm.log(.infinity) == .infinity)
        #expect(Fdlibm.log1p(negativeZero).bitPattern == negativeZero.bitPattern)
        #expect(Fdlibm.log1p(-1) == negativeInfinity)
        #expect(Fdlibm.log1p(-1.5).isNaN)
        #expect(Fdlibm.log1p(.nan).isNaN)
        #expect(Fdlibm.log1p(.infinity) == .infinity)
        #expect(Fdlibm.exp(negativeZero) == one)
        #expect(Fdlibm.exp(.infinity) == .infinity)
        #expect(Fdlibm.exp(negativeInfinity).bitPattern == positiveZero.bitPattern)
        #expect(Fdlibm.exp(.nan).isNaN)
    }
}

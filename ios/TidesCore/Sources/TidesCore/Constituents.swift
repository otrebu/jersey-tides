import Foundation

/// Tidal constituent catalog — 62 base and compound constituents.
///
/// Port of the constituents section of `packages/core/src/engine.ts`.
/// Compound constituents evaluate member-by-member (not via the combined
/// coefficient vector), matching the TS reduction order exactly.

/// One tidal constituent: Doodson coefficients plus its equilibrium argument,
/// speed, and Schureman nodal corrections.
public struct Constituent: Sendable {
    public let name: String
    /// Doodson coefficients in `[T+h-s, s, h, p, N, pp, 90]` order.
    public let coefficients: [Double]
    /// Equilibrium argument V in degrees (un-normalised).
    public let value: @Sendable (Astro) -> Double
    /// Angular speed in degrees/hour.
    public let speed: @Sendable (Astro) -> Double
    /// Nodal phase correction u in degrees.
    public let u: @Sendable (Astro) -> Double
    /// Nodal amplitude factor f (dimensionless).
    public let f: @Sendable (Astro) -> Double
}

private func base(
    _ name: String,
    _ coefficients: [Double],
    u: @escaping @Sendable (Astro) -> Double = uZero,
    f: @escaping @Sendable (Astro) -> Double = fUnity
) -> Constituent {
    Constituent(
        name: name,
        coefficients: coefficients,
        value: { a in
            var sum = 0.0
            for i in coefficients.indices {
                sum += coefficients[i] * a.doodsonValues[i]
            }
            return sum
        },
        speed: { a in
            var sum = 0.0
            for i in coefficients.indices {
                sum += coefficients[i] * a.doodsonSpeeds[i]
            }
            return sum
        },
        u: u,
        f: f
    )
}

private func compound(_ name: String, _ members: [(c: Constituent, factor: Double)]) -> Constituent {
    let coefficients = (0 ..< 7).map { i in
        members.reduce(0.0) { $0 + $1.c.coefficients[i] * $1.factor }
    }
    return Constituent(
        name: name,
        coefficients: coefficients,
        value: { a in members.reduce(0.0) { $0 + $1.c.value(a) * $1.factor } },
        speed: { a in members.reduce(0.0) { $0 + $1.c.speed(a) * $1.factor } },
        u: { a in members.reduce(0.0) { $0 + $1.c.u(a) * $1.factor } },
        f: { a in members.reduce(1.0) { $0 * pow($1.c.f(a), abs($1.factor)) } }
    )
}

/// The full constituent catalog, keyed by name.
public let CATALOG: [String: Constituent] = {
    // Base constituents.
    let Z0 = base("Z0", [0, 0, 0, 0, 0, 0, 0])
    let SA = base("SA", [0, 0, 1, 0, 0, 0, 0])
    let SSA = base("SSA", [0, 0, 2, 0, 0, 0, 0])
    let MM = base("MM", [0, 1, 0, -1, 0, 0, 0], u: uZero, f: fMm)
    let MF = base("MF", [0, 2, 0, 0, 0, 0, 0], u: uMf, f: fMf)
    let Q1 = base("Q1", [1, -2, 0, 1, 0, 0, 1], u: uO1, f: fO1)
    let O1 = base("O1", [1, -1, 0, 0, 0, 0, 1], u: uO1, f: fO1)
    let K1 = base("K1", [1, 1, 0, 0, 0, 0, -1], u: uK1, f: fK1)
    let J1 = base("J1", [1, 2, 0, -1, 0, 0, -1], u: uJ1, f: fJ1)
    let M1 = base("M1", [1, 0, 0, 0, 0, 0, 1], u: uM1, f: fM1)
    let P1 = base("P1", [1, 1, -2, 0, 0, 0, 1])
    let S1 = base("S1", [1, 1, -1, 0, 0, 0, 0])
    let OO1 = base("OO1", [1, 3, 0, 0, 0, 0, -1], u: uOO1, f: fOO1)
    let TwoN2 = base("2N2", [2, -2, 0, 2, 0, 0, 0], u: uM2, f: fM2)
    let N2 = base("N2", [2, -1, 0, 1, 0, 0, 0], u: uM2, f: fM2)
    let NU2 = base("NU2", [2, -1, 2, -1, 0, 0, 0], u: uM2, f: fM2)
    let M2 = base("M2", [2, 0, 0, 0, 0, 0, 0], u: uM2, f: fM2)
    let LAM2 = base("LAM2", [2, 1, -2, 1, 0, 0, 2], u: uM2, f: fM2)
    let L2 = base("L2", [2, 1, 0, -1, 0, 0, 2], u: uL2, f: fL2)
    let T2 = base("T2", [2, 2, -3, 0, 0, 1, 0])
    let S2 = base("S2", [2, 2, -2, 0, 0, 0, 0])
    let R2 = base("R2", [2, 2, -1, 0, 0, -1, 2])
    let K2 = base("K2", [2, 2, 0, 0, 0, 0, 0], u: uK2, f: fK2)
    let M3 = base("M3", [3, 0, 0, 0, 0, 0, 0], u: { a in 1.5 * uM2(a) }, f: { a in pow(fM2(a), 1.5) })

    // Compound constituents (as in neaps).
    let MSF = compound("MSF", [(S2, 1), (M2, -1)])
    let TwoQ1 = compound("2Q1", [(N2, 1), (J1, -1)])
    let RHO = compound("RHO", [(NU2, 1), (K1, -1)])
    let MU2 = compound("MU2", [(M2, 2), (S2, -1)])
    let TwoSM2 = compound("2SM2", [(S2, 2), (M2, -1)])
    let TwoMK3 = compound("2MK3", [(M2, 1), (O1, 1)]) // identical members to MO3 — verbatim from neaps
    let MK3 = compound("MK3", [(M2, 1), (K1, 1)])
    let MN4 = compound("MN4", [(M2, 1), (N2, 1)])
    let M4 = compound("M4", [(M2, 2)])
    let MS4 = compound("MS4", [(M2, 1), (S2, 1)])
    let S4 = compound("S4", [(S2, 2)])
    let M6 = compound("M6", [(M2, 3)])
    let S6 = compound("S6", [(S2, 3)])
    let M8 = compound("M8", [(M2, 4)])
    // Extended shallow-water catalog (beyond neaps).
    let MA2 = compound("MA2", [(M2, 1), (SA, -1)])
    let MB2 = compound("MB2", [(M2, 1), (SA, 1)])
    let MSN2 = compound("MSN2", [(M2, 1), (S2, 1), (N2, -1)])
    let MNS2 = compound("MNS2", [(M2, 1), (N2, 1), (S2, -1)])
    let MKS2 = compound("MKS2", [(M2, 1), (K2, 1), (S2, -1)])
    let MO3 = compound("MO3", [(M2, 1), (O1, 1)])
    let SO3 = compound("SO3", [(S2, 1), (O1, 1)])
    let SK3 = compound("SK3", [(S2, 1), (K1, 1)])
    let MK4 = compound("MK4", [(M2, 1), (K2, 1)])
    let SN4 = compound("SN4", [(S2, 1), (N2, 1)])
    let SK4 = compound("SK4", [(S2, 1), (K2, 1)])
    let TwoMS6 = compound("2MS6", [(M2, 2), (S2, 1)])
    let TwoMN6 = compound("2MN6", [(M2, 2), (N2, 1)])
    let MSN6 = compound("MSN6", [(M2, 1), (S2, 1), (N2, 1)])
    let TwoSM6 = compound("2SM6", [(S2, 2), (M2, 1)])
    let MSK6 = compound("MSK6", [(M2, 1), (S2, 1), (K2, 1)])
    let ThreeMS8 = compound("3MS8", [(M2, 3), (S2, 1)])
    let TwoMS8 = compound("2MS8", [(M2, 2), (S2, 2)])
    let TwoMSN8 = compound("2MSN8", [(M2, 2), (S2, 1), (N2, 1)])
    let M10 = compound("M10", [(M2, 5)])
    let TwoMK5 = compound("2MK5", [(M2, 2), (K1, 1)])
    let TwoSK5 = compound("2SK5", [(S2, 2), (K1, 1)])
    let TwoMO5 = compound("2MO5", [(M2, 2), (O1, 1)])
    let ThreeMK7 = compound("3MK7", [(M2, 3), (K1, 1)])
    let ThreeMO7 = compound("3MO7", [(M2, 3), (O1, 1)])
    let TwoMN2 = compound("2MN2", [(M2, 2), (N2, -1)])

    let all: [Constituent] = [
        Z0, SA, SSA, MM, MF, Q1, O1, K1, J1, M1, P1, S1, OO1,
        TwoN2, N2, NU2, M2, LAM2, L2, T2, S2, R2, K2, M3,
        MSF, TwoQ1, RHO, MU2, TwoSM2, TwoMK3, MK3, MN4, M4, MS4, S4, M6, S6, M8,
        MA2, MB2, MSN2, MNS2, MKS2, MO3, SO3, SK3, MK4, SN4, SK4,
        TwoMS6, TwoMN6, MSN6, TwoSM6, MSK6, ThreeMS8, TwoMS8, TwoMSN8, M10,
        TwoMK5, TwoSK5, TwoMO5, ThreeMK7, ThreeMO7, TwoMN2,
    ]
    return Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })
}()

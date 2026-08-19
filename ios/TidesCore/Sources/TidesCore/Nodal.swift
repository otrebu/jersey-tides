import Foundation

/// Schureman nodal corrections — the amplitude factors `f` (dimensionless)
/// and phase corrections `u` (degrees) applied per constituent.
///
/// Port of the nodal-corrections section of `packages/core/src/engine.ts`.
/// Every formula reads the normalised (0–360°) stored `Astro` values, exactly
/// as the TS closures do.

func fUnity(_: Astro) -> Double { 1 }
func uZero(_: Astro) -> Double { 0 }

func fMm(_ a: Astro) -> Double {
    let omega = d2r * a.omega, i = d2r * a.i, I = d2r * a.I
    let mean = (2.0 / 3 - sin(omega) * sin(omega)) * (1 - (3.0 / 2) * sin(i) * sin(i))
    return (2.0 / 3 - sin(I) * sin(I)) / mean
}

func fMf(_ a: Astro) -> Double {
    let omega = d2r * a.omega, i = d2r * a.i, I = d2r * a.I
    return sin(I) * sin(I) / (sin(omega) * sin(omega) * pow(cos(0.5 * i), 4))
}

func fO1(_ a: Astro) -> Double {
    let omega = d2r * a.omega, i = d2r * a.i, I = d2r * a.I
    let mean = sin(omega) * pow(cos(0.5 * omega), 2) * pow(cos(0.5 * i), 4)
    return (sin(I) * pow(cos(0.5 * I), 2)) / mean
}

func fJ1(_ a: Astro) -> Double {
    let omega = d2r * a.omega, i = d2r * a.i, I = d2r * a.I
    return sin(2 * I) / (sin(2 * omega) * (1 - (3.0 / 2) * sin(i) * sin(i)))
}

func fOO1(_ a: Astro) -> Double {
    let omega = d2r * a.omega, i = d2r * a.i, I = d2r * a.I
    let mean = sin(omega) * pow(sin(0.5 * omega), 2) * pow(cos(0.5 * i), 4)
    return (sin(I) * pow(sin(0.5 * I), 2)) / mean
}

func fM2(_ a: Astro) -> Double {
    let omega = d2r * a.omega, i = d2r * a.i, I = d2r * a.I
    return pow(cos(0.5 * I), 4) / (pow(cos(0.5 * omega), 4) * pow(cos(0.5 * i), 4))
}

func fK1(_ a: Astro) -> Double {
    let omega = d2r * a.omega, i = d2r * a.i, I = d2r * a.I, nu = d2r * a.nu
    let mean = 0.5023 * (sin(2 * omega) * (1 - (3.0 / 2) * sin(i) * sin(i))) + 0.1681
    return pow(0.2523 * pow(sin(2 * I), 2) + 0.1689 * sin(2 * I) * cos(nu) + 0.0283, 0.5) / mean
}

func fL2(_ a: Astro) -> Double {
    let P = d2r * a.P, I = d2r * a.I
    let rAInv = pow(1 - 12 * pow(tan(0.5 * I), 2) * cos(2 * P) + 36 * pow(tan(0.5 * I), 4), 0.5)
    return fM2(a) * rAInv
}

func fK2(_ a: Astro) -> Double {
    let omega = d2r * a.omega, i = d2r * a.i, I = d2r * a.I, nu = d2r * a.nu
    let mean = 0.5023 * (sin(omega) * sin(omega) * (1 - (3.0 / 2) * sin(i) * sin(i))) + 0.0365
    return pow(0.2523 * pow(sin(I), 4) + 0.0367 * pow(sin(I), 2) * cos(2 * nu) + 0.0013, 0.5) / mean
}

func fM1(_ a: Astro) -> Double {
    let P = d2r * a.P, I = d2r * a.I
    let qAInv = pow(
        0.25 + 1.5 * cos(I) * cos(2 * P) * pow(cos(0.5 * I), -0.5) + 2.25 * pow(cos(I), 2) * pow(cos(0.5 * I), -4),
        0.5
    )
    return fO1(a) * qAInv
}

func uMf(_ a: Astro) -> Double { -2 * a.xi }
func uO1(_ a: Astro) -> Double { 2 * a.xi - a.nu }
func uJ1(_ a: Astro) -> Double { -a.nu }
func uOO1(_ a: Astro) -> Double { -2 * a.xi - a.nu }
func uM2(_ a: Astro) -> Double { 2 * a.xi - 2 * a.nu }
func uK1(_ a: Astro) -> Double { -a.nup }

func uL2(_ a: Astro) -> Double {
    let I = d2r * a.I, P = d2r * a.P
    let R = r2d * atan(sin(2 * P) / ((1.0 / 6) * pow(tan(0.5 * I), -2) - cos(2 * P)))
    return 2 * a.xi - 2 * a.nu - R
}

func uK2(_ a: Astro) -> Double { -2 * a.nupp }

func uM1(_ a: Astro) -> Double {
    let I = d2r * a.I, P = d2r * a.P
    let Q = r2d * atan(((5 * cos(I) - 1) / (7 * cos(I) + 1)) * tan(P))
    return a.xi - a.nu + Q
}

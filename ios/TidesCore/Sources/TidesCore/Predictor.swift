import Foundation

/// Harmonic prediction: basis evaluation and the level/slope predictor.
///
/// Port of the prediction section of `packages/core/src/engine.ts`.

/// One fitted harmonic constant: constituent name, amplitude in metres and
/// Greenwich phase lag in degrees.
public struct HarmonicConstant: Sendable, Hashable {
    public let name: String
    public let amplitude: Double
    public let phaseGMT: Double

    public init(name: String, amplitude: Double, phaseGMT: Double) {
        self.name = name
        self.amplitude = amplitude
        self.phaseGMT = phaseGMT
    }
}

/// Harmonic basis sample for one constituent at one instant.
public struct BasisSample: Sendable {
    /// f·cos(V+u) — multiply by A·cos(g).
    public let c: Double
    /// f·sin(V+u) — multiply by A·sin(g).
    public let s: Double
    /// d/dt of `c` in 1/hour.
    public let dc: Double
    /// d/dt of `s` in 1/hour.
    public let ds: Double
}

/// Evaluate the harmonic basis for the given constituent names at time `t`.
/// Traps on unknown names — validate through `Predictor.init` for a
/// recoverable error.
public func evalBasis(names: [String], at t: Date) -> [BasisSample] {
    let a = astro(t)
    return names.map { name in
        guard let model = CATALOG[name] else {
            preconditionFailure("Unknown constituent: \(name)")
        }
        let theta = d2r * (model.value(a) + model.u(a))
        let omega = d2r * model.speed(a) // rad/hour
        let f = model.f(a)
        return BasisSample(
            c: f * cos(theta),
            s: f * sin(theta),
            dc: -f * omega * sin(theta),
            ds: f * omega * cos(theta)
        )
    }
}

public enum TideEngineError: Error, Sendable, Equatable {
    case unknownConstituents([String])
}

/// Tide level/slope predictor for a set of harmonic constants.
/// Output is metres relative to the constants' reference (no datum).
public struct Predictor: Sendable {
    let models: [Constituent]
    /// Per-constituent A·cos(g).
    let x: [Double]
    /// Per-constituent A·sin(g).
    let y: [Double]

    /// Throws `TideEngineError.unknownConstituents` when any name is not in
    /// the catalog.
    public init(constants: [HarmonicConstant]) throws {
        let unknown = constants.filter { CATALOG[$0.name] == nil }
        guard unknown.isEmpty else {
            throw TideEngineError.unknownConstituents(unknown.map(\.name))
        }
        models = constants.map { CATALOG[$0.name]! }
        x = constants.map { $0.amplitude * cos(d2r * $0.phaseGMT) }
        y = constants.map { $0.amplitude * sin(d2r * $0.phaseGMT) }
    }

    /// Tide level in metres (no datum) at `t`.
    public func levelAt(_ t: Date) -> Double {
        levelAt(ms: t.msSinceEpoch)
    }

    /// d(level)/dt in metres/hour at `t`.
    public func slopeAt(_ t: Date) -> Double {
        slopeAt(ms: t.msSinceEpoch)
    }

    func levelAt(ms: Double) -> Double {
        let a = astroAt(ms: ms)
        var sum = 0.0
        for k in models.indices {
            let model = models[k]
            let theta = d2r * (model.value(a) + model.u(a))
            let f = model.f(a)
            sum += x[k] * (f * cos(theta)) + y[k] * (f * sin(theta))
        }
        return sum
    }

    func slopeAt(ms: Double) -> Double {
        let a = astroAt(ms: ms)
        var sum = 0.0
        for k in models.indices {
            let model = models[k]
            let theta = d2r * (model.value(a) + model.u(a))
            let omega = d2r * model.speed(a) // rad/hour
            let f = model.f(a)
            sum += x[k] * (-f * omega * sin(theta)) + y[k] * (f * omega * cos(theta))
        }
        return sum
    }
}

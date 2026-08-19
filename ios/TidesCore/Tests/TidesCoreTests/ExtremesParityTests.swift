import Foundation
import Testing
@testable import TidesCore

/// Golden replay of extremes.json: 42 two-day windows of raw predictor
/// extremes (no datum) — exact counts, per-index time within 1 s, level
/// within 1 mm, exact type — plus the semantic invariants the TS suite pins.
struct ExtremesParityTests {
    struct Window: Decodable {
        struct WindowExtreme: Decodable {
            let utc: String
            let level: Double
            let type: String
        }

        let fromUtc: String
        let toUtc: String
        let extremes: [WindowExtreme]
    }

    static func predictor() throws -> Predictor {
        try Predictor(constants: StHelier.constituents)
    }

    @Test func reproducesEveryRawEngineExtreme() throws {
        let windows: [Window] = try Fixtures.load("extremes.json")
        #expect(windows.count == 42)
        let predictor = try Self.predictor()
        for window in windows {
            let got = predictor.extremes(
                from: Fixtures.date(window.fromUtc),
                to: Fixtures.date(window.toUtc)
            )
            #expect(got.count == window.extremes.count, "window \(window.fromUtc)")
            guard got.count == window.extremes.count else { continue }
            for (index, want) in window.extremes.enumerated() {
                let g = got[index]
                #expect(
                    abs(g.time.msSinceEpoch - Fixtures.ms(want.utc)) <= Fixtures.timeEpsMs,
                    "window \(window.fromUtc) extreme \(index): got \(g.time), want \(want.utc)"
                )
                #expect(
                    abs(g.level - want.level) <= Fixtures.heightEpsMetres,
                    "window \(window.fromUtc) extreme \(index): got \(g.level), want \(want.level)"
                )
                #expect(g.type.rawValue == want.type, "window \(window.fromUtc) extreme \(index)")
            }
        }
    }

    @Test func computedExtremesAlternateWithinEachWindow() throws {
        let windows: [Window] = try Fixtures.load("extremes.json")
        let predictor = try Self.predictor()
        for window in windows {
            let got = predictor.extremes(
                from: Fixtures.date(window.fromUtc),
                to: Fixtures.date(window.toUtc)
            )
            #expect(got.count > 1, "window \(window.fromUtc)")
            for i in 1 ..< got.count {
                #expect(got[i].type != got[i - 1].type, "window \(window.fromUtc) extreme \(i)")
            }
        }
    }

    @Test func slopeIsNearZeroAtEveryFixtureExtreme() throws {
        let windows: [Window] = try Fixtures.load("extremes.json")
        let predictor = try Self.predictor()
        for window in windows {
            for extreme in window.extremes {
                let slope = predictor.slopeAt(Fixtures.date(extreme.utc))
                #expect(abs(slope) < 1e-4, "\(extreme.utc): slope \(slope)")
            }
        }
    }
}

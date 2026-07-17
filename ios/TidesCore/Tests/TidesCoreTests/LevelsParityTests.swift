import Foundation
import Testing
@testable import TidesCore

/// Golden replay of levels.json: 2000 pseudo-random instants (2023–2030) of
/// raw predictor output (no datum), each within 1 mm of the TS engine.
struct LevelsParityTests {
    struct Level: Decodable {
        let utc: String
        let level: Double
    }

    @Test func reproducesEveryRawEngineLevel() throws {
        let levels: [Level] = try Fixtures.load("levels.json")
        #expect(levels.count == 2000)
        let predictor = try Predictor(constants: StHelier.constituents)
        for entry in levels {
            let got = predictor.levelAt(Fixtures.date(entry.utc))
            #expect(
                abs(got - entry.level) <= Fixtures.heightEpsMetres,
                "\(entry.utc): got \(got), want \(entry.level)"
            )
        }
    }
}

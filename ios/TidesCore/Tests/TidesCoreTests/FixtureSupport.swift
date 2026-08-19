import Foundation
@testable import TidesCore

/// Shared fixture loading + strict ISO-8601 parsing for the parity suites.
///
/// The cross-language parity contract (packages/core/test/fixtures.test.ts):
/// heights within 1e-9 m, instants within 1 s, day lengths exactly equal.
enum Fixtures {
    static let heightEpsMetres = 1e-9
    static let timeEpsMs = 1000.0

    static let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // TidesCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // TidesCore
        .deletingLastPathComponent() // ios
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("packages/core/fixtures")

    static func load<T: Decodable>(_ name: String) throws -> T {
        let data = try Data(contentsOf: url.appendingPathComponent(name))
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Epoch milliseconds of a strict `YYYY-MM-DDTHH:MM:SS[.fff]Z` fixture
    /// string — exact integer-ms arithmetic, no formatter rounding.
    static func ms(_ iso: String) -> Double {
        precondition(iso.hasSuffix("Z"), "expected UTC ISO string: \(iso)")
        let parts = iso.dropLast().split(separator: "T")
        let ymd = parts[0].split(separator: "-").map { Int($0)! }
        let hms = parts[1].split(separator: ":")
        let secParts = hms[2].split(separator: ".")
        let fraction = secParts.count > 1 ? String(secParts[1]) : "0"
        let millis = Int(fraction.padding(toLength: 3, withPad: "0", startingAt: 0))!
        let days = daysFromCivil(year: ymd[0], month: ymd[1], day: ymd[2])
        return Double(days) * 86_400_000
            + Double(Int(hms[0])!) * 3_600_000
            + Double(Int(hms[1])!) * 60_000
            + Double(Int(secParts[0])!) * 1000
            + Double(millis)
    }

    static func date(_ iso: String) -> Date {
        Date(msSinceEpoch: ms(iso))
    }
}

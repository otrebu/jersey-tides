/// Swift port of `@u-b/tides-core` (packages/core/src/engine.ts).
///
/// Port order: astro → nodal corrections → constituent catalog → predictor →
/// extremes, gated at every step by the golden-fixture parity tests in
/// `Tests/TidesCoreTests` (levels within 1 mm, extreme times within 1 s).
///
/// Port traps (from the plan of record): JS `%` keeps the dividend's sign like
/// Swift's `truncatingRemainder` — every angle normalisation must go through a
/// positive `mod360`; JS epochs are milliseconds while Foundation speaks
/// seconds; `Double` is IEEE-754 binary64 on both sides.
public enum TidesCore {
    /// The npm package version this port tracks.
    public static let trackingVersion = "0.1.0"
}

import Foundation

/// Injectable now-source. Named `TideClock` (not `Clock`) so it never collides
/// with Swift Concurrency's `Clock` protocol.
struct TideClock: Sendable {
    private let nowProvider: @Sendable () -> Date

    init(now nowProvider: @escaping @Sendable () -> Date) {
        self.nowProvider = nowProvider
    }

    /// The current instant (frozen in harness runs).
    var now: Date { nowProvider() }

    /// Wall clock.
    static let system = TideClock { Date() }

    /// A clock pinned to one instant — deterministic screenshots.
    static func frozen(at instant: Date) -> TideClock {
        TideClock { instant }
    }

    /// Honors the DEBUG launch argument `-frozen-now <ISO8601>`
    /// (e.g. `-frozen-now 2026-07-17T12:00:00Z`); falls back to the wall clock.
    static func resolved(from arguments: [String] = ProcessInfo.processInfo.arguments) -> TideClock {
        #if DEBUG
        if let index = arguments.firstIndex(of: "-frozen-now"),
           arguments.indices.contains(index + 1),
           let instant = ISO8601DateFormatter().date(from: arguments[index + 1]) {
            return .frozen(at: instant)
        }
        #endif
        return .system
    }
}

/// The single composition point for the engine + clock (the swap point).
enum EngineProvider {
    /// The engine every surface uses: the TidesCore-backed adapter (fixture
    /// parity vs `packages/core/fixtures`, gate: `cd ios/TidesCore && swift
    /// test`). `SyntheticEngine` remains available for deterministic unit
    /// tests (`Tests/` instantiate it directly).
    static let engine: any TideEngine = TidesCoreEngine()

    /// Process-wide clock; frozen when launched with `-frozen-now`.
    static let clock: TideClock = .resolved()
}

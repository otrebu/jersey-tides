# Native iOS target (reserved — phase 3)

A SwiftPM `TidesCore` package (Swift port of `packages/core/src/engine.ts`) +
SwiftUI app + WidgetKit extension. Lives at the repo root because a Swift
package is not a pnpm workspace member.

The contract for the port is the committed golden fixtures: Swift tests read
`../packages/core/fixtures/*.json` and must reproduce levels within 1 mm and
extreme times within 1 s. Port order: astro → nodal corrections → catalog →
predictor → extremes, gated by `swift test` at every step (no Xcode or
simulator needed for the engine).

Key facts from the Jul 2026 research (see the plan artifact):

- Scaffold with XcodeGen + Xcode synced folders; the generated `.xcodeproj`
  stays gitignored — never edit `.pbxproj` by hand or by agent.
- The widget imports `TidesCore` and computes in-process → no App Group →
  a free personal Apple team suffices for on-device testing.
- WidgetKit: timeline entries are free, reloads are budgeted — one reload/day
  carrying 10-minute entries covers a fully-offline widget.
- Claude Code drives the loop via XcodeBuildMCP
  (`claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp`) and
  Apple's `xcrun mcpbridge` (DocumentationSearch, RenderPreview).
- Port traps: JS `%` vs Swift `truncatingRemainder` on negative angles
  (`mod360`), ms vs seconds epoch, `Double` is IEEE-754 on both sides.

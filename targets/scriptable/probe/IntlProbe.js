// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: deep-blue; icon-glyph: clock;

// Gate 1 probe: does this device's JavaScriptCore give correct Europe/Jersey
// offsets across DST boundaries via Intl? Exercises the exact Intl surface
// @u-b/tides-core uses (packages/core/src/time.ts): formatToParts with
// hourCycle 'h23' for offset math, toLocaleTimeString for display.
// Run IN-APP (not as a widget) and report the verdict line.

const TZ = 'Europe/Jersey'

// Verbatim port of tzOffsetMinutes from packages/core/src/time.ts
function tzOffsetMinutes(utc, timeZone) {
  const dtf = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
    hourCycle: 'h23'
  })
  const fields = {}
  for (const part of dtf.formatToParts(utc)) {
    if (part.type !== 'literal') fields[part.type] = Number(part.value)
  }
  const localAsUtc = Date.UTC(fields.year, fields.month - 1, fields.day, fields.hour, fields.minute, fields.second)
  return Math.round((localAsUtc - utc.getTime()) / 60000)
}

// [UTC instant, expected offset (min), expected local HH:MM]
const CASES = [
  ['2026-01-15T12:00:00Z', 0, '12:00'], // deep winter, GMT
  ['2026-03-29T00:59:00Z', 0, '00:59'], // 1 min before spring-forward
  ['2026-03-29T01:00:00Z', 60, '02:00'], // spring-forward instant
  ['2026-07-12T12:00:00Z', 60, '13:00'], // mid-summer, BST
  ['2026-07-12T23:30:00Z', 60, '00:30'], // crosses local midnight (h23 check)
  ['2026-10-25T00:59:00Z', 60, '01:59'], // 1 min before fall-back
  ['2026-10-25T01:00:00Z', 0, '01:00'], // fall-back instant
  ['2027-03-28T01:00:00Z', 60, '02:00'], // next year's spring-forward
  ['2027-10-31T01:00:00Z', 0, '01:00'] // next year's fall-back
]

const lines = []
lines.push(`Intl probe — iOS ${Device.systemVersion()} · ${Device.model()}`)
try {
  lines.push(`device tz: ${Intl.DateTimeFormat().resolvedOptions().timeZone}`)
} catch (e) {
  lines.push(`resolvedOptions() threw: ${e}`)
}

let failures = 0
for (const [iso, expOff, expLocal] of CASES) {
  let verdict
  try {
    const d = new Date(iso)
    const off = tzOffsetMinutes(d, TZ)
    const local = d.toLocaleTimeString('en-GB', { timeZone: TZ, hour: '2-digit', minute: '2-digit' })
    const ok = off === expOff && local === expLocal
    if (!ok) failures++
    verdict = `${ok ? 'PASS' : 'FAIL'}  ${iso}  offset=${off} (exp ${expOff})  local=${local} (exp ${expLocal})`
  } catch (e) {
    failures++
    verdict = `FAIL  ${iso}  threw: ${e}`
  }
  lines.push(verdict)
}

// Display-formatting smoke (informational, matches core's formatDate)
try {
  const sample = new Date('2026-07-12T12:00:00Z')
    .toLocaleDateString('en-GB', { timeZone: TZ, weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' })
  lines.push(`formatDate sample: ${sample}`)
} catch (e) {
  lines.push(`formatDate threw: ${e}`)
}

lines.push(
  failures === 0
    ? `VERDICT: PASS ${CASES.length}/${CASES.length} — Intl safe to rely on`
    : `VERDICT: FAIL (${failures}/${CASES.length} bad) — wire the UK-DST fallback`
)

const report = lines.join('\n')
console.log(report)
await QuickLook.present(report)
Script.complete()

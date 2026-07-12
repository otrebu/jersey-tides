import { stHelier } from '@u-b/tides-core/stations/st-helier'

declare const BUILD_TIME: string

// Pipeline placeholder: proves esbuild -> iCloud -> JavaScriptCore end to end
// with the real engine bundled and computing. Deliberately Intl-free — the
// full widget lands once gate 1 (probe/IntlProbe.js) passes on-device.
async function main(): Promise<void> {
  const now = new Date()
  const height = stHelier.levelAt(now)
  const rising = stHelier.slopeAt(now) > 0

  const w = new ListWidget()
  w.backgroundColor = new Color('#f8f8f8')

  const title = w.addText('JERSEY TIDES')
  title.font = Font.boldMonospacedSystemFont(12)
  title.textColor = new Color('#111111')

  w.addSpacer(6)

  const level = w.addText(`${height.toFixed(1)}m ${rising ? '▲' : '▼'}`)
  level.font = Font.regularMonospacedSystemFont(28)
  level.textColor = new Color('#111111')

  w.addSpacer(6)

  const note = w.addText(`pipeline OK · ${BUILD_TIME}`)
  note.font = Font.regularMonospacedSystemFont(9)
  note.textColor = new Color('#555555')

  if (config.runsInWidget) {
    Script.setWidget(w)
  } else {
    await w.presentSmall()
  }
  Script.complete()
}

main()

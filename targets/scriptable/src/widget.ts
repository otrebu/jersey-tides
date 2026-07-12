import { formatDate } from '@u-b/tides-core'
import { drawDayChart } from './chart.ts'
import type { TideVM } from './data.ts'
import { TZ, arrow, buildVM, fmtExtreme } from './data.ts'
import { circularImage, inlineText, rectangularImage } from './lock.ts'
import { INK, MUTED, PAPER, mono, monoBold } from './theme.ts'

function smallWidget(vm: TideVM): ListWidget {
  const w = new ListWidget()
  w.backgroundColor = PAPER
  w.setPadding(14, 14, 12, 14)
  const title = w.addText('ST HELIER')
  title.font = mono(10)
  title.textColor = MUTED
  w.addSpacer(4)
  const level = w.addText(`${vm.height.toFixed(1)}m ${arrow(vm.rising)}`)
  level.font = monoBold(28)
  level.textColor = INK
  level.lineLimit = 1
  level.minimumScaleFactor = 0.6
  w.addSpacer()
  vm.next.forEach((e, i) => {
    if (i > 0) w.addSpacer(3)
    const line = w.addText(fmtExtreme(e))
    line.font = mono(11)
    line.textColor = INK
    line.lineLimit = 1
    line.minimumScaleFactor = 0.8
  })
  return w
}

function mediumWidget(vm: TideVM): ListWidget {
  const w = new ListWidget()
  w.backgroundColor = PAPER
  w.setPadding(12, 14, 12, 12)
  const root = w.addStack()
  root.layoutHorizontally()
  root.centerAlignContent()

  const left = root.addStack()
  left.layoutVertically()
  left.size = new Size(108, 0) // fixed width, flexible height
  const title = left.addText('ST HELIER')
  title.font = mono(10)
  title.textColor = MUTED
  left.addSpacer(2)
  const date = left.addText(formatDate(vm.now, TZ))
  date.font = mono(9)
  date.textColor = MUTED
  date.lineLimit = 1
  date.minimumScaleFactor = 0.8
  left.addSpacer(10)
  const level = left.addText(`${vm.height.toFixed(1)}m ${arrow(vm.rising)}`)
  level.font = monoBold(24)
  level.textColor = INK
  level.lineLimit = 1
  level.minimumScaleFactor = 0.6
  left.addSpacer(10)
  vm.next.forEach((e, i) => {
    if (i > 0) left.addSpacer(3)
    const line = left.addText(fmtExtreme(e))
    line.font = mono(10)
    line.textColor = INK
    line.lineLimit = 1
    line.minimumScaleFactor = 0.8
  })

  root.addSpacer(6)
  const chart = root.addImage(drawDayChart(vm, 186, 128))
  chart.resizable = false
  return w
}

function rectangularWidget(vm: TideVM): ListWidget {
  const w = new ListWidget()
  w.addAccessoryWidgetBackground = true
  w.setPadding(4, 6, 4, 6)
  const img = w.addImage(rectangularImage(vm))
  img.resizable = false
  img.leftAlignImage()
  return w
}

function circularWidget(vm: TideVM): ListWidget {
  const w = new ListWidget()
  w.addAccessoryWidgetBackground = true
  w.setPadding(0, 0, 0, 0)
  const img = w.addImage(circularImage(vm))
  img.resizable = false
  img.centerAlignImage()
  return w
}

function inlineWidget(vm: TideVM): ListWidget {
  const w = new ListWidget()
  const line = w.addText(inlineText(vm))
  line.font = mono(12)
  return w
}

function buildWidget(vm: TideVM): ListWidget {
  const family = config.widgetFamily
  let w: ListWidget
  if (family === 'small') w = smallWidget(vm)
  else if (family === 'accessoryRectangular') w = rectangularWidget(vm)
  else if (family === 'accessoryCircular') w = circularWidget(vm)
  else if (family === 'accessoryInline') w = inlineWidget(vm)
  else w = mediumWidget(vm) // medium, large, extraLarge, and in-app preview

  // Best-effort refresh anchored to the next extreme; a stale render stays
  // correct because every displayed time is absolute.
  w.refreshAfterDate = vm.refreshAfter
  w.url = `scriptable:///run?scriptName=${encodeURIComponent(Script.name())}`
  return w
}

// Widgets surface no console, so a failure must degrade to a readable tile
// (and still call Script.complete) rather than the system error placeholder.
function errorWidget(err: unknown): ListWidget {
  const w = new ListWidget()
  w.backgroundColor = PAPER
  const title = w.addText('JERSEY TIDES — ERROR')
  title.font = mono(10)
  title.textColor = MUTED
  w.addSpacer(4)
  const msg = w.addText(String(err))
  msg.font = mono(10)
  msg.textColor = INK
  msg.lineLimit = 4
  w.refreshAfterDate = new Date(Date.now() + 15 * 60_000)
  return w
}

async function main(): Promise<void> {
  let w: ListWidget
  try {
    w = buildWidget(buildVM())
  } catch (err) {
    w = errorWidget(err)
  }
  try {
    if (config.runsInWidget) {
      Script.setWidget(w)
    } else {
      await w.presentMedium()
    }
  } finally {
    Script.complete()
  }
}

main()

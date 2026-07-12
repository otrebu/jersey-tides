import { formatTime } from '@u-b/tides-core'
import type { TideVM } from './data.ts'
import { TZ } from './data.ts'
import { AREA, INK, MUTED, PAPER, mono } from './theme.ts'

const PAD_TOP = 26 // two 9pt label rows above HW dots
const PAD_BOTTOM = 28 // two 9pt label rows below LW dots
const DOT_R = 3
const LABEL_W = 46
const LABEL_H = 11

function clamp(v: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, v))
}

/**
 * True sampled day curve: area fill under a 2pt line, HW/LW dots with
 * absolute time + height labels, sunrise/sunset ticks on the baseline and a
 * now marker. The x axis spans the local calendar day linearly in UTC between
 * the true day bounds, so 23/25h DST days are exact by construction.
 */
export function drawDayChart(vm: TideVM, width: number, height: number): Image {
  const ctx = new DrawContext()
  ctx.size = new Size(width, height)
  ctx.opaque = false
  ctx.respectScreenScale = true

  const plotTop = PAD_TOP
  const plotBottom = height - PAD_BOTTOM
  const t0 = vm.dayStart.getTime()
  const t1 = vm.dayEnd.getTime()
  const x = (t: Date): number => ((t.getTime() - t0) / (t1 - t0)) * width

  // y scale fits the day's true range (sampled curve + exact extreme heights)
  const heights = vm.points.map((p) => p.height)
  for (const e of vm.dayExtremes) heights.push(e.height)
  const rawLo = Math.min(...heights)
  const rawHi = Math.max(...heights)
  const pad = Math.max(rawHi - rawLo, 1) * 0.06
  const lo = rawLo - pad
  const hi = rawHi + pad
  const y = (h: number): number => plotBottom - ((h - lo) / (hi - lo)) * (plotBottom - plotTop)

  // area under the curve
  const area = new Path()
  area.move(new Point(0, plotBottom))
  for (const p of vm.points) area.addLine(new Point(x(p.time), y(p.height)))
  area.addLine(new Point(width, plotBottom))
  area.closeSubpath()
  ctx.setFillColor(AREA)
  ctx.addPath(area)
  ctx.fillPath()

  // the curve itself
  const line = new Path()
  vm.points.forEach((p, i) => {
    const pt = new Point(x(p.time), y(p.height))
    if (i === 0) line.move(pt)
    else line.addLine(pt)
  })
  ctx.setStrokeColor(INK)
  ctx.setLineWidth(2)
  ctx.addPath(line)
  ctx.strokePath()

  // baseline
  const base = new Path()
  base.move(new Point(0, plotBottom))
  base.addLine(new Point(width, plotBottom))
  ctx.setLineWidth(1)
  ctx.addPath(base)
  ctx.strokePath()

  // sunrise/sunset ticks rising from the baseline
  ctx.setStrokeColor(MUTED)
  ctx.setLineWidth(1.5)
  for (const sun of [vm.sunrise, vm.sunset]) {
    if (!sun) continue
    const sx = x(sun)
    if (sx < 0 || sx > width) continue
    const tick = new Path()
    tick.move(new Point(sx, plotBottom - 6))
    tick.addLine(new Point(sx, plotBottom))
    ctx.addPath(tick)
    ctx.strokePath()
  }

  // HW/LW dots with time + height labels (HW above, LW below)
  ctx.setFont(mono(9))
  ctx.setTextAlignedCenter()
  for (const e of vm.dayExtremes) {
    const ex = x(e.time)
    const ey = y(e.height)
    ctx.setFillColor(INK)
    ctx.fillEllipse(new Rect(ex - DOT_R, ey - DOT_R, DOT_R * 2, DOT_R * 2))
    const lx = clamp(ex - LABEL_W / 2, 0, width - LABEL_W)
    const up = e.type === 'high'
    const timeY = up ? ey - 25 : ey + 6
    const heightY = up ? ey - 14.5 : ey + 16.5
    ctx.setTextColor(INK)
    ctx.drawTextInRect(formatTime(e.time, TZ), new Rect(lx, timeY, LABEL_W, LABEL_H))
    ctx.setTextColor(MUTED)
    ctx.drawTextInRect(`${e.height.toFixed(1)}m`, new Rect(lx, heightY, LABEL_W, LABEL_H))
  }

  // now marker: thin vertical line + ring dot on the curve
  const nx = clamp(x(vm.now), 1, width - 1)
  const nowLine = new Path()
  nowLine.move(new Point(nx, plotTop - 2))
  nowLine.addLine(new Point(nx, plotBottom))
  ctx.setStrokeColor(MUTED)
  ctx.setLineWidth(1)
  ctx.addPath(nowLine)
  ctx.strokePath()
  const ny = y(vm.height)
  ctx.setFillColor(PAPER)
  ctx.fillEllipse(new Rect(nx - 5.5, ny - 5.5, 11, 11))
  ctx.setFillColor(INK)
  ctx.fillEllipse(new Rect(nx - 3.5, ny - 3.5, 7, 7))

  return ctx.getImage()
}

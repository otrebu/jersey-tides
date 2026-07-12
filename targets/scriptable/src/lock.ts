import type { TideVM } from './data.ts'
import { arrow, fmtExtreme } from './data.ts'
import { WHITE, WHITE_DIM, WHITE_FAINT, mono, monoBold } from './theme.ts'

// Lock-screen accessories are reduced by iOS to one image + one text, so each
// family renders its whole face into a single DrawContext image.

/** accessoryRectangular: current level + the next two extremes, three lines. */
export function rectangularImage(vm: TideVM): Image {
  const W = 150
  const H = 60
  const ctx = new DrawContext()
  ctx.size = new Size(W, H)
  ctx.opaque = false
  ctx.respectScreenScale = true
  ctx.setTextAlignedLeft()
  ctx.setTextColor(WHITE)
  ctx.setFont(monoBold(20))
  ctx.drawTextInRect(`${vm.height.toFixed(1)}m ${arrow(vm.rising)}`, new Rect(0, 0, W, 24))
  ctx.setFont(mono(11))
  if (vm.next[0]) ctx.drawTextInRect(fmtExtreme(vm.next[0]), new Rect(0, 28, W, 14))
  ctx.setTextColor(WHITE_DIM)
  if (vm.next[1]) ctx.drawTextInRect(fmtExtreme(vm.next[1]), new Rect(0, 44, W, 14))
  return ctx.getImage()
}

/** accessoryCircular: 270° gauge of where the level sits in today's LW-HW range. */
export function circularImage(vm: TideVM): Image {
  const S = 66
  const C = S / 2
  const R = 26
  const ctx = new DrawContext()
  ctx.size = new Size(S, S)
  ctx.opaque = false
  ctx.respectScreenScale = true

  const hs = vm.dayExtremes.map((e) => e.height)
  const lo = hs.length > 0 ? Math.min(...hs) : vm.height - 1
  const hi = hs.length > 0 ? Math.max(...hs) : vm.height + 1
  const frac = Math.min(1, Math.max(0, (vm.height - lo) / Math.max(hi - lo, 0.1)))

  // fuel-gauge sweep: 135° (bottom-left) through top to 405° (bottom-right)
  ctx.setLineWidth(5)
  ctx.setStrokeColor(WHITE_FAINT)
  ctx.addPath(arcPath(C, C, R, 135, 405))
  ctx.strokePath()
  if (frac > 0.01) {
    ctx.setStrokeColor(WHITE)
    ctx.addPath(arcPath(C, C, R, 135, 135 + 270 * frac))
    ctx.strokePath()
  }

  ctx.setTextAlignedCenter()
  ctx.setTextColor(WHITE)
  ctx.setFont(monoBold(15))
  ctx.drawTextInRect(vm.height.toFixed(1), new Rect(0, 20, S, 17))
  ctx.setFont(mono(9))
  ctx.drawTextInRect(arrow(vm.rising), new Rect(0, 37, S, 11))
  return ctx.getImage()
}

/** accessoryInline: a single line of text. */
export function inlineText(vm: TideVM): string {
  const next = vm.next[0]
  return next ? `${arrow(vm.rising)} ${fmtExtreme(next)}` : `${arrow(vm.rising)} ${vm.height.toFixed(1)}m`
}

// DrawContext has no arc primitive; approximate with 5° line segments.
function arcPath(cx: number, cy: number, r: number, fromDeg: number, toDeg: number): Path {
  const path = new Path()
  const steps = Math.max(2, Math.ceil((toDeg - fromDeg) / 5))
  for (let i = 0; i <= steps; i++) {
    const a = ((fromDeg + ((toDeg - fromDeg) * i) / steps) * Math.PI) / 180
    const p = new Point(cx + r * Math.cos(a), cy + r * Math.sin(a))
    if (i === 0) path.move(p)
    else path.addLine(p)
  }
  return path
}

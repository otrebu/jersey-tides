import { SunriseIcon, SunsetIcon } from './icons.tsx'
import type { TideExtreme } from '@u-b/tides-core'
import type { SunTimes } from '@u-b/tides-core/almanac'

export interface TideCurveProps {
  extremes: TideExtreme[]
  /** UTC instant of the viewed day's local midnight */
  dayStart: Date
  currentTime: Date | null
  isToday: boolean
  sunTimes: SunTimes
}

export function TideCurve({ extremes, dayStart, currentTime, isToday, sunTimes }: TideCurveProps) {
  if (extremes.length < 2) return null

  const width = 340
  const height = 80
  const viewBox = `0 0 ${width} ${height}`
  const pad = { top: 16, bottom: 18, left: 30, right: 8 }
  const cw = width - pad.left - pad.right
  const ch = height - pad.top - pad.bottom

  const hourOf = (t: Date) => (t.getTime() - dayStart.getTime()) / 3.6e6

  const tidePoints = extremes.map(e => ({
    hour: hourOf(e.time),
    height: e.height,
    type: e.type
  }))

  const pts: Array<{ hour: number; height: number }> = []

  if (tidePoints[0].hour > 0) {
    pts.push({ hour: 0, height: (tidePoints[0].height + tidePoints[1].height) / 2 })
  }

  for (let i = 0; i < tidePoints.length - 1; i++) {
    const t1 = tidePoints[i]
    const t2 = tidePoints[i + 1]
    pts.push({ hour: t1.hour, height: t1.height })
    for (let j = 1; j < 10; j++) {
      const p = j / 10
      const h = t1.hour + (t2.hour - t1.hour) * p
      pts.push({ hour: h, height: t1.height + (t2.height - t1.height) * (1 - Math.cos(p * Math.PI)) / 2 })
    }
  }

  const last = tidePoints[tidePoints.length - 1]
  pts.push({ hour: last.hour, height: last.height })

  if (last.hour < 24) {
    pts.push({ hour: 24, height: (last.height + tidePoints[tidePoints.length - 2].height) / 2 })
  }

  const minH = Math.min(...pts.map(p => p.height)) - 0.5
  const maxH = Math.max(...pts.map(p => p.height)) + 0.5
  const range = maxH - minH

  const pathD = pts.map((p, i) => {
    const x = (pad.left + (p.hour / 24) * cw).toFixed(1)
    const y = (pad.top + ch - ((p.height - minH) / range) * ch).toFixed(1)
    return `${i === 0 ? 'M' : 'L'} ${x} ${y}`
  }).join(' ')

  const curX = currentTime ? pad.left + (hourOf(currentTime) / 24) * cw : null

  const srX = sunTimes.sunrise
    ? pad.left + (hourOf(sunTimes.sunrise) / 24) * cw
    : null
  const ssX = sunTimes.sunset
    ? pad.left + (hourOf(sunTimes.sunset) / 24) * cw
    : null

  return (
    <svg viewBox={viewBox} className="block w-full h-auto">
      {/* Night shading */}
      {srX && (
        <rect x={pad.left} y={pad.top} width={srX - pad.left} height={ch} className="fill-[var(--ubtide-text)] opacity-[0.06]" />
      )}
      {ssX && (
        <rect x={ssX} y={pad.top} width={pad.left + cw - ssX} height={ch} className="fill-[var(--ubtide-text)] opacity-[0.06]" />
      )}

      {/* Time grid lines */}
      {[0, 6, 12, 18, 24].map(h => (
        <g key={h}>
          <line
            x1={pad.left + (h / 24) * cw}
            y1={pad.top}
            x2={pad.left + (h / 24) * cw}
            y2={pad.top + ch}
            className="stroke-[var(--ubtide-text-muted)] opacity-30"
            strokeWidth="1"
          />
          <text
            x={pad.left + (h / 24) * cw}
            y={height - 3}
            textAnchor="middle"
            className="text-[9px] fill-[var(--ubtide-text-muted)]"
          >
            {String(h % 24).padStart(2, '0')}
          </text>
        </g>
      ))}

      {/* Sunrise line and icon */}
      {srX && (
        <>
          <line x1={srX} y1={pad.top} x2={srX} y2={pad.top + ch} className="stroke-[var(--ubtide-sun-color)] opacity-70" strokeWidth="1.5" />
          <g transform={`translate(${srX - 6}, ${pad.top - 14})`}>
            <SunriseIcon color="var(--ubtide-sun-color)" size={12} />
          </g>
        </>
      )}

      {/* Sunset line and icon */}
      {ssX && (
        <>
          <line x1={ssX} y1={pad.top} x2={ssX} y2={pad.top + ch} className="stroke-[var(--ubtide-sun-color)] opacity-70" strokeWidth="1.5" />
          <g transform={`translate(${ssX - 6}, ${pad.top - 14})`}>
            <SunsetIcon color="var(--ubtide-sun-color)" size={12} />
          </g>
        </>
      )}

      {/* Y-axis labels */}
      <text x={pad.left - 4} y={pad.top + 4} textAnchor="end" className="text-[9px] fill-[var(--ubtide-text-muted)]">
        {maxH.toFixed(0)}m
      </text>
      <text x={pad.left - 4} y={pad.top + ch} textAnchor="end" className="text-[9px] fill-[var(--ubtide-text-muted)]">
        {minH.toFixed(0)}m
      </text>

      {/* Tide curve */}
      <path d={pathD} fill="none" className="stroke-[var(--ubtide-curve-stroke)]" strokeWidth="2.5" />

      {/* Extreme points */}
      {tidePoints.map((tp, i) => {
        const x = pad.left + (tp.hour / 24) * cw
        const y = pad.top + ch - ((tp.height - minH) / range) * ch
        return (
          <circle
            key={i}
            cx={x}
            cy={y}
            r="4.5"
            className={`stroke-[var(--ubtide-curve-stroke)] stroke-2 ${
              tp.type === 'high' ? 'fill-[var(--ubtide-curve-dot)]' : 'fill-[var(--ubtide-curve-dot-low)]'
            }`}
          />
        )
      })}

      {/* Current time indicator */}
      {isToday && curX !== null && (
        <line
          x1={curX}
          y1={pad.top}
          x2={curX}
          y2={pad.top + ch}
          className="stroke-[var(--ubtide-accent)]"
          strokeWidth="2"
          strokeDasharray="4,3"
        />
      )}
    </svg>
  )
}

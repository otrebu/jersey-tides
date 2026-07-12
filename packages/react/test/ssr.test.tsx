import { renderToString } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import { formatDate, formatTime } from '@u-b/tides-core'
import { stHelier } from '@u-b/tides-core/stations/st-helier'
import { TideWidget } from '../src/index.ts'

const fixed = new Date('2026-07-11T10:30:00Z')
const TZ = 'Europe/Jersey'

describe('TideWidget SSR', () => {
  it('renders deterministically without window', () => {
    expect(typeof window).toBe('undefined')

    const html = renderToString(<TideWidget now={fixed} initialDate={fixed} />)

    const highWater = stHelier.dayExtremes(fixed).find(e => e.type === 'high')
    expect(highWater).toBeDefined()
    expect(html).toContain(formatTime(highWater!.time, TZ))
    expect(html).toContain(formatDate(fixed, TZ))
    expect(html).toContain('ST HELIER, JERSEY')
    expect(html).toContain('49.18°N')

    expect(renderToString(<TideWidget now={fixed} initialDate={fixed} />)).toBe(html)

    // Snapshot is shared between the TZ=UTC and TZ=America/New_York runs of
    // this suite, so a match under both proves host-TZ independence.
    expect(html).toMatchSnapshot()
  })

  it('renders the same markup after simulating a client environment', () => {
    const server = renderToString(<TideWidget now={fixed} initialDate={fixed} />)
    const g = globalThis as { window?: unknown }
    g.window = g.window ?? {}
    try {
      const client = renderToString(<TideWidget now={fixed} initialDate={fixed} />)
      expect(client).toBe(server)
    } finally {
      delete g.window
    }
  })

  it('renders a stable skeleton with no props (no clock reads during render)', () => {
    const a = renderToString(<TideWidget />)
    const b = renderToString(<TideWidget />)
    expect(a).toBe(b)
    expect(a).toContain('ubtide-calendar')
    expect(a).toContain('ubtide-events')
    expect(a).toMatchSnapshot()
  })
})

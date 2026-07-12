# @u-b/tides-react

React tide widget for [@u-b/tides-core](../core). ESM-only, `'use client'` components.

```tsx
import { TideWidget } from '@u-b/tides-react'
import '@u-b/tides-react/styles.css'

<TideWidget />
```

The widget fills its container (`width: 100%`) — constrain it with a wrapper.
Pass `now`/`initialDate` for fully deterministic (SSR-safe) output; without
them the clock resolves in a mount effect and the server-rendered skeleton
hydrates cleanly.

## Theming

Everything renders inside a `.ubtide` wrapper. Override the `--ubtide-*`
custom properties in CSS, or pass `theme={{ cardBg: '#fff', ... }}` (camelCase
keys, see `TideTheme` in `theme.ts` for the full token list). Sections carry
stable hook classes: `ubtide-current`, `ubtide-calendar`, `ubtide-curve`,
`ubtide-events`.

Card borders default to `--ubtide-card-border-width: 0px`: the pre-split
`--card-border` compound token (`2px solid #111`) produced an invalid
declaration and never rendered, so 0px preserves the established look. Set

```css
.ubtide { --ubtide-card-border-width: 2px; }
```

to restore the originally intended brutalist card border.

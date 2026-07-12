# @u-b/tides-react

React tide widget for [@u-b/tides-core](../core). ESM-only, ships `'use client'`
components with a fully namespaced (`.ubtide`) theming contract.

```bash
pnpm add @u-b/tides-react
```

`@u-b/tides-core` comes along as a dependency. `react` / `react-dom`
(18.2+ or 19) are peer dependencies you already have.

## Usage

Two lines — import the stylesheet once, drop the widget in:

```tsx
import { TideWidget } from '@u-b/tides-react'
import '@u-b/tides-react/styles.css'

export default function Page() {
  return <TideWidget />
}
```

### Consumer contract

The widget renders its own content only. You own the page chrome:

- **Import the stylesheet** — `import '@u-b/tides-react/styles.css'` exactly
  once in your app. Without it the widget is unstyled.
- **Supply the page shell** — the widget no longer paints a page background,
  min-height, or padding. Give the page its own `min-h-screen`, padding, and
  background/text colors.
- **Constrain the width yourself** — every widget section is `width: 100%`
  (fluid). Wrap it in your own `max-width` container if you want a column.
- **Known stylesheet globals** — besides the `.ubtide`-scoped rules,
  `styles.css` carries Tailwind v4's declaration-only layers: `:root` theme
  variables (`--spacing`, `--text-*`, `--color-*`, …) and `--tw-*` `@property`
  fallbacks. They restyle nothing by themselves, but if your page also uses
  Tailwind v4 with customized theme values, load your own stylesheet *after*
  this one so yours wins.

```tsx
<main className="min-h-screen bg-white text-black p-4">
  <div className="mx-auto max-w-md">
    <TideWidget />
  </div>
</main>
```

### SSR / RSC

The components carry the `'use client'` directive and render fine from a Server
Component tree (Next.js App Router, etc.). For deterministic server output pass
`now` / `initialDate`; without them the clock resolves in a mount effect and the
server-rendered skeleton hydrates cleanly.

## Theming

Everything renders inside a `.ubtide` wrapper, and every themable value is a
`--ubtide-*` CSS custom property on it. There are three ways to theme, in
increasing specificity.

### 1. Defaults

Ship nothing and you get the brutalist monochrome default (see table below).

### 2. CSS cascade

Override tokens anywhere in your own CSS — they inherit down from `.ubtide`:

```css
.ubtide {
  --ubtide-accent: #0aa;
  --ubtide-card-border-width: 2px; /* see note below */
}
```

### 3. `theme` prop

Pass a partial theme object (camelCase keys map 1:1 to the kebab tokens):

```tsx
<TideWidget theme={{ accent: '#0aa', cardBg: '#fff', cardBorderWidth: '2px' }} />
```

### Regional class hooks

Each section carries a stable class you can target without touching internals:
`ubtide-current`, `ubtide-calendar`, `ubtide-curve`, `ubtide-events`.

```css
.ubtide-events { font-size: 0.9rem; }
```

### Card border note

`--ubtide-card-border-width` defaults to **`0px`**. The historical pre-split
`--card-border` compound token produced an invalid declaration and never
rendered, so `0px` preserves the established look. For the intended brutalist
card border:

```css
.ubtide { --ubtide-card-border-width: 2px; }
```

### Token table

| Token | Colors / controls | Default |
| --- | --- | --- |
| `--ubtide-bg` | Widget background | `transparent` |
| `--ubtide-card-bg` | Card surfaces (curve panel, calendar cells) | `#fff` |
| `--ubtide-card-border-width` | Card border thickness (`0px` historical, `2px` brutalist) | `0px` |
| `--ubtide-card-border-color` | Card border color | `#111` |
| `--ubtide-border-strong` | Strong dividers / structural borders | `#111` |
| `--ubtide-header-bg` | Header strip background | `#f0f0f0` |
| `--ubtide-header-text` | Header text | `#111` |
| `--ubtide-text` | Primary text | `#111` |
| `--ubtide-text-muted` | Secondary / muted text | `#555` |
| `--ubtide-accent` | Accent color | `#111` |
| `--ubtide-current-bg` | Current-level panel background | `#111` |
| `--ubtide-current-text` | Current-level text | `#fff` |
| `--ubtide-current-muted` | Current-level muted text | `#aaa` |
| `--ubtide-high-bg` | High-tide badge background | `#111` |
| `--ubtide-high-text` | High-tide badge text | `#fff` |
| `--ubtide-low-bg` | Low-tide badge background | `#fff` |
| `--ubtide-low-text` | Low-tide badge text | `#111` |
| `--ubtide-low-border` | Low-tide badge border | `#111` |
| `--ubtide-selected-bg` | Selected calendar day background | `#111` |
| `--ubtide-selected-text` | Selected calendar day text | `#fff` |
| `--ubtide-today-border` | Today cell border | `#111` |
| `--ubtide-curve-stroke` | Tide curve line | `#111` |
| `--ubtide-curve-dot` | Curve extreme dots (high) | `#111` |
| `--ubtide-curve-dot-low` | Curve extreme dots (low fill) | `#fff` |
| `--ubtide-bar-bg` | Level bar track | `#e5e5e5` |
| `--ubtide-bar-fill` | Level bar fill | `#111` |
| `--ubtide-sun-moon-bg` | Sun/moon almanac panel background | `#f5f5f5` |
| `--ubtide-sun-color` | Sun glyph color | `#d97706` |
| `--ubtide-font-family` | Widget font family | `'SF Mono', Consolas, monospace` |
| `--ubtide-border-radius` | Corner radius | `0` |
| `--ubtide-shadow` | Box shadow | `none` |

## Composing individual components

`TideWidget` is the batteries-included layout. You can also compose the pieces
yourself and drive them from the headless `@u-b/tides-core` station:

```tsx
import { CurrentLevel, Calendar, TideCurve, TideEvents } from '@u-b/tides-react'
import { stHelier } from '@u-b/tides-core/stations/st-helier'
```

Exported components: `TideWidget`, `Calendar`, `CurrentLevel`, `TideCurve`,
`TideEvents`, plus the `TideTheme` type. Each component ships its own
`*Props` type.

## License

MIT

import type { CSSProperties } from 'react'

/**
 * The frozen ubtide theming contract. Every themable value is a CSS custom
 * property on the `.ubtide` wrapper. Full token list (defaults in styles.css):
 *
 *   --ubtide-bg                  --ubtide-low-bg
 *   --ubtide-card-bg             --ubtide-low-text
 *   --ubtide-card-border-width   --ubtide-low-border
 *   --ubtide-card-border-color   --ubtide-selected-bg
 *   --ubtide-border-strong       --ubtide-selected-text
 *   --ubtide-header-bg           --ubtide-today-border
 *   --ubtide-header-text         --ubtide-curve-stroke
 *   --ubtide-text                --ubtide-curve-dot
 *   --ubtide-text-muted          --ubtide-curve-dot-low
 *   --ubtide-accent              --ubtide-bar-bg
 *   --ubtide-current-bg          --ubtide-bar-fill
 *   --ubtide-current-text        --ubtide-sun-moon-bg
 *   --ubtide-current-muted       --ubtide-sun-color
 *   --ubtide-high-bg             --ubtide-font-family
 *   --ubtide-high-text           --ubtide-border-radius
 *                                --ubtide-shadow
 *
 * Camel-cased keys below map 1:1 onto the kebab-cased tokens.
 */
export interface TideTheme {
  bg: string
  cardBg: string
  cardBorderWidth: string
  cardBorderColor: string
  borderStrong: string
  headerBg: string
  headerText: string
  text: string
  textMuted: string
  accent: string
  currentBg: string
  currentText: string
  currentMuted: string
  highBg: string
  highText: string
  lowBg: string
  lowText: string
  lowBorder: string
  selectedBg: string
  selectedText: string
  todayBorder: string
  curveStroke: string
  curveDot: string
  curveDotLow: string
  barBg: string
  barFill: string
  sunMoonBg: string
  sunColor: string
  fontFamily: string
  borderRadius: string
  shadow: string
}

/** Inline-style form of a partial theme: `{ '--ubtide-card-bg': '#fff', ... }`. */
export function themeToStyle(theme: Partial<TideTheme>): CSSProperties {
  const style: Record<string, string> = {}
  for (const [key, value] of Object.entries(theme)) {
    if (value == null) continue
    style[`--ubtide-${key.replace(/[A-Z]/g, c => `-${c.toLowerCase()}`)}`] = value
  }
  return style as CSSProperties
}

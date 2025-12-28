import { createContext, useContext, useEffect, type ReactNode } from 'react'
import { THEME } from '@/lib/themes'

const ThemeContext = createContext<boolean>(false)

export function ThemeProvider({ children }: { children: ReactNode }) {
  useEffect(() => {
    const root = document.documentElement

    root.style.setProperty('--bg', THEME.bg)
    root.style.setProperty('--card-bg', THEME.cardBg)
    root.style.setProperty('--card-border', THEME.cardBorder)
    root.style.setProperty('--header-bg', THEME.headerBg)
    root.style.setProperty('--header-text', THEME.headerText)
    root.style.setProperty('--text', THEME.text)
    root.style.setProperty('--text-muted', THEME.textMuted)
    root.style.setProperty('--accent', THEME.accent)
    root.style.setProperty('--current-bg', THEME.currentBg)
    root.style.setProperty('--current-text', THEME.currentText)
    root.style.setProperty('--current-muted', THEME.currentMuted)
    root.style.setProperty('--high-bg', THEME.highBg)
    root.style.setProperty('--high-text', THEME.highText)
    root.style.setProperty('--low-bg', THEME.lowBg)
    root.style.setProperty('--low-text', THEME.lowText)
    root.style.setProperty('--low-border', THEME.lowBorder)
    root.style.setProperty('--selected-bg', THEME.selectedBg)
    root.style.setProperty('--selected-text', THEME.selectedText)
    root.style.setProperty('--today-border', THEME.todayBorder)
    root.style.setProperty('--curve-stroke', THEME.curveStroke)
    root.style.setProperty('--curve-dot', THEME.curveDot)
    root.style.setProperty('--curve-dot-low', THEME.curveDotLow)
    root.style.setProperty('--bar-bg', THEME.barBg)
    root.style.setProperty('--bar-fill', THEME.barFill)
    root.style.setProperty('--sun-moon-bg', THEME.sunMoonBg)
    root.style.setProperty('--sun-color', THEME.sunColor)
    root.style.setProperty('--font-family', THEME.fontFamily)
    root.style.setProperty('--border-radius', THEME.borderRadius)
    root.style.setProperty('--shadow', THEME.shadow)
  }, [])

  return (
    <ThemeContext.Provider value={true}>
      {children}
    </ThemeContext.Provider>
  )
}

export function useTheme() {
  const context = useContext(ThemeContext)
  if (context === undefined) {
    throw new Error('useTheme must be used within a ThemeProvider')
  }
}

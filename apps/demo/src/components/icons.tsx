interface IconProps {
  color?: string
  size?: number
}

export function SunIcon({ color = '#f59e0b', size = 20 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="5" fill={color} />
      <g stroke={color} strokeWidth="2" strokeLinecap="round">
        <line x1="12" y1="1" x2="12" y2="4" />
        <line x1="12" y1="20" x2="12" y2="23" />
        <line x1="1" y1="12" x2="4" y2="12" />
        <line x1="20" y1="12" x2="23" y2="12" />
        <line x1="4.22" y1="4.22" x2="6.34" y2="6.34" />
        <line x1="17.66" y1="17.66" x2="19.78" y2="19.78" />
        <line x1="4.22" y1="19.78" x2="6.34" y2="17.66" />
        <line x1="17.66" y1="6.34" x2="19.78" y2="4.22" />
      </g>
    </svg>
  )
}

export function SunriseIcon({ color = '#f59e0b', size = 20 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <line x1="1" y1="18" x2="23" y2="18" stroke={color} strokeWidth="2" strokeLinecap="round" />
      <circle cx="12" cy="14" r="4" fill={color} />
      <path d="M12 1L8 5h3v3h2V5h3L12 1z" fill={color} />
    </svg>
  )
}

export function SunsetIcon({ color = '#f59e0b', size = 20 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <line x1="1" y1="18" x2="23" y2="18" stroke={color} strokeWidth="2" strokeLinecap="round" />
      <circle cx="12" cy="16" r="4" fill={color} opacity="0.6" />
      <path d="M12 8L8 4h3V1h2v3h3L12 8z" fill={color} opacity="0.7" />
    </svg>
  )
}

// Brutalist palette: ink on paper, fixed light — a deliberate statement, not
// adaptive. Lock-screen accessories use white; iOS applies its own vibrancy.
export const INK = new Color('#111111')
export const PAPER = new Color('#f8f8f8')
export const MUTED = new Color('#555555')
export const AREA = new Color('#e4e4e4')
export const WHITE = new Color('#ffffff')
export const WHITE_DIM = new Color('#ffffff', 0.75)
export const WHITE_FAINT = new Color('#ffffff', 0.3)

export const mono = (size: number): Font => Font.regularMonospacedSystemFont(size)
export const monoBold = (size: number): Font => Font.boldMonospacedSystemFont(size)

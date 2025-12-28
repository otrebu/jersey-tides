// St. Helier, Jersey coordinates
export const JERSEY_LAT = 49.2138
export const JERSEY_LON = -2.1358

// Chart datum offset (meters above LAT - Lowest Astronomical Tide)
export const DATUM = 6.0036

// Harmonic constituents for St. Helier
// Format required by @neaps/tide-predictor
export const ST_HELIER_CONSTITUENTS = [
  { name: 'M2', amplitude: 3.3467, phase_GMT: 182.48 },
  { name: 'S2', amplitude: 1.2994, phase_GMT: 232.24 },
  { name: 'N2', amplitude: 0.6576, phase_GMT: 165.59 },
  { name: 'K2', amplitude: 0.3715, phase_GMT: 230.12 },
  { name: 'K1', amplitude: 0.0928, phase_GMT: 97.78 },
  { name: 'O1', amplitude: 0.0798, phase_GMT: 346.61 },
  { name: 'M4', amplitude: 0.1926, phase_GMT: 300.81 },
  { name: 'MS4', amplitude: 0.1451, phase_GMT: 357.81 }
]

// Day and month abbreviations
export const DAYS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'] as const
export const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'] as const

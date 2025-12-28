// St. Helier, Jersey coordinates (from PSMSL station 1795)
export const JERSEY_LAT = 49.183
export const JERSEY_LON = -2.117

// Chart datum offset (meters above LAT - Lowest Astronomical Tide)
export const DATUM = 6.0036

// Harmonic constituents for St. Helier
// Source: TICON-3 dataset (GESLA-3 derived, 1992-2021 observations)
// DOI: https://doi.org/10.1594/PANGAEA.951610
// Format required by @neaps/tide-predictor
export const ST_HELIER_CONSTITUENTS = [
  // Semi-diurnal (principal)
  { name: 'M2', amplitude: 3.3432, phase_GMT: 182.11 },
  { name: 'S2', amplitude: 1.3029, phase_GMT: 231.87 },
  { name: 'N2', amplitude: 0.6570, phase_GMT: 165.31 },
  { name: 'K2', amplitude: 0.3695, phase_GMT: 229.53 },
  { name: 'L2', amplitude: 0.1449, phase_GMT: 162.09 },
  { name: 'T2', amplitude: 0.0712, phase_GMT: 219.13 },
  { name: '2N2', amplitude: 0.0872, phase_GMT: 149.02 },
  { name: 'R2', amplitude: 0.0140, phase_GMT: 259.38 },
  // Diurnal
  { name: 'K1', amplitude: 0.0931, phase_GMT: 97.27 },
  { name: 'O1', amplitude: 0.0800, phase_GMT: 346.45 },
  { name: 'P1', amplitude: 0.0328, phase_GMT: 89.84 },
  { name: 'Q1', amplitude: 0.0229, phase_GMT: 303.93 },
  { name: 'J1', amplitude: 0.0047, phase_GMT: 178.67 },
  { name: 'M1', amplitude: 0.0070, phase_GMT: 110.27 },
  { name: 'S1', amplitude: 0.0066, phase_GMT: 60.46 },
  { name: 'OO1', amplitude: 0.0039, phase_GMT: 236.92 },
  { name: '2Q1', amplitude: 0.0039, phase_GMT: 259.33 },
  // Shallow water overtides
  { name: 'M4', amplitude: 0.1918, phase_GMT: 300.82 },
  { name: 'MS4', amplitude: 0.1459, phase_GMT: 356.89 },
  { name: 'MN4', amplitude: 0.0703, phase_GMT: 277.73 },
  { name: 'S4', amplitude: 0.0213, phase_GMT: 81.42 },
  { name: 'M6', amplitude: 0.0100, phase_GMT: 0.57 },
  { name: 'M8', amplitude: 0.0015, phase_GMT: 145.76 },
  // Long period
  { name: 'SA', amplitude: 0.0664, phase_GMT: 298.77 },
  { name: 'SSA', amplitude: 0.0279, phase_GMT: 123.06 },
  { name: 'MM', amplitude: 0.0173, phase_GMT: 213.98 },
  { name: 'MF', amplitude: 0.0177, phase_GMT: 207.36 },
  { name: 'MSF', amplitude: 0.0282, phase_GMT: 222.52 },
  // Ter-diurnal
  { name: 'M3', amplitude: 0.0258, phase_GMT: 174.57 },
]

// Day and month abbreviations
export const DAYS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'] as const
export const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'] as const

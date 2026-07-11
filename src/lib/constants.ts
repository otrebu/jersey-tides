// St. Helier, Jersey coordinates (from PSMSL station 1795)
export const JERSEY_LAT = 49.183
export const JERSEY_LON = -2.117

// Chart datum offset (meters above LAT - Lowest Astronomical Tide)
export const DATUM = 6.0947

// Harmonic constituents for St. Helier
// Fitted (scripts/fit-constituents.mjs) to official gov.je / NOC tide-table
// predictions: 904 high/low events spanning Jun 2023, Oct-Nov 2024 and
// Jul-Dec 2026, using @neaps/tide-predictor itself as the basis engine so its
// phase/nodal conventions are baked into the constants. Verified against
// gov.je and SHOM predictions: max height error 0.35m (see scripts/compare-official.mjs).
// Prior for the fit: TICON-3 dataset (https://doi.org/10.1594/PANGAEA.951610).
export const ST_HELIER_CONSTITUENTS = [
  // Semi-diurnal (principal)
  { name: 'M2', amplitude: 3.5138, phase_GMT: 197.53 },
  { name: 'S2', amplitude: 1.2789, phase_GMT: 244.88 },
  { name: 'N2', amplitude: 0.6170, phase_GMT: 179.66 },
  { name: 'K2', amplitude: 0.4032, phase_GMT: 243.90 },
  { name: 'L2', amplitude: 0.1091, phase_GMT: 173.67 },
  { name: 'T2', amplitude: 0.0790, phase_GMT: 205.18 },
  { name: 'R2', amplitude: 0.0143, phase_GMT: 265.73 },
  { name: '2N2', amplitude: 0.0865, phase_GMT: 150.69 },
  { name: 'MU2', amplitude: 0.1665, phase_GMT: 183.72 },
  { name: 'NU2', amplitude: 0.0460, phase_GMT: 160.94 },
  { name: 'LAM2', amplitude: 0.0433, phase_GMT: 112.34 },
  { name: '2SM2', amplitude: 0.0169, phase_GMT: 50.31 },
  // Diurnal
  { name: 'K1', amplitude: 0.0901, phase_GMT: 104.94 },
  { name: 'O1', amplitude: 0.0745, phase_GMT: 354.06 },
  { name: 'P1', amplitude: 0.0319, phase_GMT: 90.86 },
  { name: 'Q1', amplitude: 0.0212, phase_GMT: 306.00 },
  { name: 'J1', amplitude: 0.0047, phase_GMT: 179.71 },
  { name: 'M1', amplitude: 0.0063, phase_GMT: 111.17 },
  { name: 'S1', amplitude: 0.0067, phase_GMT: 60.51 },
  { name: 'OO1', amplitude: 0.0037, phase_GMT: 238.48 },
  { name: '2Q1', amplitude: 0.0038, phase_GMT: 259.93 },
  // Shallow water overtides
  { name: 'M4', amplitude: 0.1549, phase_GMT: 325.54 },
  { name: 'MS4', amplitude: 0.1179, phase_GMT: 14.44 },
  { name: 'MN4', amplitude: 0.0635, phase_GMT: 289.37 },
  { name: 'S4', amplitude: 0.0200, phase_GMT: 87.67 },
  { name: 'M6', amplitude: 0.1654, phase_GMT: 41.19 },
  { name: 'S6', amplitude: 0.0011, phase_GMT: 195.29 },
  { name: 'M8', amplitude: 0.0175, phase_GMT: 159.88 },
  // Long period
  { name: 'SA', amplitude: 0.0528, phase_GMT: 283.15 },
  { name: 'SSA', amplitude: 0.0209, phase_GMT: 118.57 },
  { name: 'MM', amplitude: 0.0162, phase_GMT: 210.33 },
  { name: 'MF', amplitude: 0.0084, phase_GMT: 227.56 },
  { name: 'MSF', amplitude: 0.0177, phase_GMT: 230.47 },
  // Ter-diurnal
  { name: 'M3', amplitude: 0.0256, phase_GMT: 179.45 },
  { name: 'MK3', amplitude: 0.0025, phase_GMT: 277.40 },
  { name: '2MK3', amplitude: 0.0020, phase_GMT: 183.78 },
]

// Day and month abbreviations
export const DAYS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'] as const
export const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'] as const

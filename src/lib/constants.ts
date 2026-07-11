// St. Helier, Jersey coordinates (from PSMSL station 1795)
export const JERSEY_LAT = 49.183
export const JERSEY_LON = -2.117

// Chart datum offset (meters above LAT - Lowest Astronomical Tide)
export const DATUM = 6.1006

// Harmonic constituents for St. Helier — fitted to official gov.je / NOC tide
// tables (scripts/fit2.mjs): 904 high/low events spanning Jun 2023, Oct-Nov 2024
// and Jul-Dec 2026, with curvature-weighted zero-slope rows so extreme TIMING is
// fitted, not just heights. Basis/conventions are those of src/lib/engine.ts —
// these constants are engine-specific, do not use with other predictors.
// Verified vs gov.je + SHOM (scripts/compare2.mjs): max height error 0.28m,
// max extreme-time error 8.2min across 931 events from 4 sources.
// Prior: TICON-3 dataset (https://doi.org/10.1594/PANGAEA.951610).
export const ST_HELIER_CONSTITUENTS = [
  // Semi-diurnal
  { name: 'M2', amplitude: 3.3945, phase_GMT: 181.89 },
  { name: 'S2', amplitude: 1.2756, phase_GMT: 230.98 },
  { name: 'N2', amplitude: 0.629, phase_GMT: 164.09 },
  { name: 'K2', amplitude: 0.3275, phase_GMT: 230.55 },
  { name: 'L2', amplitude: 0.0992, phase_GMT: 165.59 },
  { name: 'T2', amplitude: 0.0679, phase_GMT: 222.49 },
  { name: 'R2', amplitude: 0.0136, phase_GMT: 260.36 },
  { name: '2N2', amplitude: 0.071, phase_GMT: 143.89 },
  { name: 'MU2', amplitude: 0.2557, phase_GMT: 188.87 },
  { name: 'NU2', amplitude: 0.0998, phase_GMT: 143.96 },
  { name: 'LAM2', amplitude: 0.064, phase_GMT: 147.99 },
  { name: '2SM2', amplitude: 0.0479, phase_GMT: 37.5 },
  { name: 'MA2', amplitude: 0.0263, phase_GMT: 72.62 },
  { name: 'MB2', amplitude: 0.007, phase_GMT: 274.27 },
  { name: 'MSN2', amplitude: 0.0313, phase_GMT: 355.83 },
  { name: 'MNS2', amplitude: 0.0399, phase_GMT: 155.9 },
  { name: 'MKS2', amplitude: 0.0312, phase_GMT: 291.94 },
  // Diurnal
  { name: 'K1', amplitude: 0.0875, phase_GMT: 94.68 },
  { name: 'O1', amplitude: 0.0767, phase_GMT: 347.4 },
  { name: 'P1', amplitude: 0.0321, phase_GMT: 86.16 },
  { name: 'Q1', amplitude: 0.0236, phase_GMT: 300.6 },
  { name: 'J1', amplitude: 0.0034, phase_GMT: 153.01 },
  { name: 'M1', amplitude: 0.0041, phase_GMT: 96.47 },
  { name: 'S1', amplitude: 0.0058, phase_GMT: 60.58 },
  { name: 'OO1', amplitude: 0.0026, phase_GMT: 218.45 },
  { name: '2Q1', amplitude: 0.0032, phase_GMT: 269.52 },
  { name: 'RHO', amplitude: 0.0006, phase_GMT: 284.08 },
  // Ter-diurnal
  { name: 'M3', amplitude: 0.0239, phase_GMT: 175.6 },
  { name: 'MK3', amplitude: 0.0075, phase_GMT: 246.85 },
  { name: '2MK3', amplitude: 0.0027, phase_GMT: 142.26 },
  { name: 'MO3', amplitude: 0.0018, phase_GMT: 95.14 },
  { name: 'SO3', amplitude: 0.004, phase_GMT: 216.44 },
  { name: 'SK3', amplitude: 0.006, phase_GMT: 268.5 },
  // Quarter-diurnal
  { name: 'M4', amplitude: 0.1897, phase_GMT: 284.49 },
  { name: 'MN4', amplitude: 0.0462, phase_GMT: 277.86 },
  { name: 'MS4', amplitude: 0.1268, phase_GMT: 343.06 },
  { name: 'S4', amplitude: 0.0097, phase_GMT: 102.21 },
  { name: 'MK4', amplitude: 0.0383, phase_GMT: 355.61 },
  { name: 'SN4', amplitude: 0.0104, phase_GMT: 8.55 },
  { name: 'SK4', amplitude: 0.0103, phase_GMT: 95.5 },
  // Sixth-diurnal
  { name: 'M6', amplitude: 0.0873, phase_GMT: 6.7 },
  { name: 'S6', amplitude: 0.0018, phase_GMT: 280.2 },
  { name: '2MS6', amplitude: 0.0398, phase_GMT: 61.38 },
  { name: '2MN6', amplitude: 0.0224, phase_GMT: 332.71 },
  { name: 'MSN6', amplitude: 0.0076, phase_GMT: 341.82 },
  { name: '2SM6', amplitude: 0.0083, phase_GMT: 79.66 },
  { name: 'MSK6', amplitude: 0.013, phase_GMT: 17.84 },
  // Eighth-diurnal and higher
  { name: 'M8', amplitude: 0.0154, phase_GMT: 77.43 },
  { name: '3MS8', amplitude: 0.0179, phase_GMT: 138.62 },
  { name: '2MS8', amplitude: 0.0034, phase_GMT: 203.29 },
  { name: '2MSN8', amplitude: 0.0043, phase_GMT: 72.89 },
  { name: 'M10', amplitude: 0.0083, phase_GMT: 146.94 },
  // Long period
  { name: 'SA', amplitude: 0.0464, phase_GMT: 273.88 },
  { name: 'SSA', amplitude: 0.0185, phase_GMT: 94.93 },
  { name: 'MM', amplitude: 0.0195, phase_GMT: 184.31 },
  { name: 'MF', amplitude: 0.0103, phase_GMT: 197.23 },
  { name: 'MSF', amplitude: 0.0073, phase_GMT: 274.8 },
]

// Day and month abbreviations
export const DAYS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'] as const
export const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'] as const

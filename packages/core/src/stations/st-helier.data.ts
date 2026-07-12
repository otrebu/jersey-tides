// St. Helier, Jersey coordinates (from PSMSL station 1795)
export const JERSEY_LAT = 49.183
export const JERSEY_LON = -2.117

// Chart datum offset (meters above LAT - Lowest Astronomical Tide)
export const DATUM = 6.0887

// Harmonic constituents for St. Helier — fitted to official gov.je / NOC tide
// tables (scripts/fit2.mjs): 904 high/low events spanning Jun 2023, Oct-Nov 2024
// and Jul-Dec 2026. Height rows + curvature-weighted zero-slope rows price extreme
// TIMING directly (beta=8, tail-boosted worst offenders); ridge priors anchored at
// TICON-4 33-year observed constants (Hart-Davis et al. 2025, seanoe 109129).
// Basis/conventions are those of the harmonic engine in ../engine.ts —
// engine-specific, do not use with other predictors.
// Verified vs 931 events from 4 official sources (scripts/compare2.mjs):
// extreme timing mean 1.2min / max 4.3min; heights mean 0.11m / max 0.39m.
// For reference, gov.je (NOC) and SHOM disagree with each other by mean 1.7min /
// max 4min over the same week.
export const ST_HELIER_CONSTITUENTS = [
  // Semi-diurnal
  { name: 'M2', amplitude: 3.338, phase_GMT: 180.01 },
  { name: 'S2', amplitude: 1.2763, phase_GMT: 229.34 },
  { name: 'N2', amplitude: 0.6662, phase_GMT: 163.01 },
  { name: 'K2', amplitude: 0.3371, phase_GMT: 232.9 },
  { name: 'L2', amplitude: 0.0928, phase_GMT: 190.2 },
  { name: 'T2', amplitude: 0.0686, phase_GMT: 226.37 },
  { name: 'R2', amplitude: 0.0131, phase_GMT: 263.41 },
  { name: '2N2', amplitude: 0.0675, phase_GMT: 153.82 },
  { name: 'MU2', amplitude: 0.2575, phase_GMT: 190.22 },
  { name: 'NU2', amplitude: 0.0884, phase_GMT: 146.68 },
  { name: 'LAM2', amplitude: 0.0705, phase_GMT: 159.47 },
  { name: '2SM2', amplitude: 0.0624, phase_GMT: 38.2 },
  { name: 'MA2', amplitude: 0.0275, phase_GMT: 87.7 },
  { name: 'MB2', amplitude: 0.0087, phase_GMT: 264.85 },
  { name: 'MSN2', amplitude: 0.0326, phase_GMT: 359.78 },
  { name: 'MNS2', amplitude: 0.0454, phase_GMT: 126.97 },
  { name: 'MKS2', amplitude: 0.0489, phase_GMT: 283.3 },
  { name: '2MN2', amplitude: 0.0123, phase_GMT: 273.05 },
  // Diurnal
  { name: 'K1', amplitude: 0.0842, phase_GMT: 98.02 },
  { name: 'O1', amplitude: 0.0728, phase_GMT: 346.26 },
  { name: 'P1', amplitude: 0.0368, phase_GMT: 89.38 },
  { name: 'Q1', amplitude: 0.0241, phase_GMT: 306.83 },
  { name: 'J1', amplitude: 0.0043, phase_GMT: 119.98 },
  { name: 'M1', amplitude: 0.0025, phase_GMT: 347.21 },
  { name: 'S1', amplitude: 0.0044, phase_GMT: 69.52 },
  { name: 'OO1', amplitude: 0.0023, phase_GMT: 171.05 },
  { name: '2Q1', amplitude: 0.002, phase_GMT: 239.65 },
  { name: 'RHO', amplitude: 0.0042, phase_GMT: 307.49 },
  // Ter-diurnal
  { name: 'M3', amplitude: 0.0253, phase_GMT: 171.39 },
  { name: 'MK3', amplitude: 0.0112, phase_GMT: 244.84 },
  { name: '2MK3', amplitude: 0.0064, phase_GMT: 127.18 },
  { name: 'MO3', amplitude: 0.0056, phase_GMT: 109.83 },
  { name: 'SO3', amplitude: 0.0023, phase_GMT: 247.7 },
  { name: 'SK3', amplitude: 0.0079, phase_GMT: 276.91 },
  // Quarter-diurnal
  { name: 'M4', amplitude: 0.2102, phase_GMT: 282.09 },
  { name: 'MN4', amplitude: 0.0442, phase_GMT: 272.12 },
  { name: 'MS4', amplitude: 0.1523, phase_GMT: 327.41 },
  { name: 'S4', amplitude: 0.0148, phase_GMT: 351.81 },
  { name: 'MK4', amplitude: 0.035, phase_GMT: 343.22 },
  { name: 'SN4', amplitude: 0.0112, phase_GMT: 4.1 },
  { name: 'SK4', amplitude: 0.0056, phase_GMT: 65.02 },
  // Fifth-diurnal
  { name: '2MK5', amplitude: 0.0016, phase_GMT: 348.14 },
  { name: '2MO5', amplitude: 0.0028, phase_GMT: 61.77 },
  // Sixth-diurnal
  { name: 'M6', amplitude: 0.0649, phase_GMT: 322.25 },
  { name: 'S6', amplitude: 0.005, phase_GMT: 280.14 },
  { name: '2MS6', amplitude: 0.0283, phase_GMT: 18.55 },
  { name: '2MN6', amplitude: 0.0426, phase_GMT: 301.04 },
  { name: 'MSN6', amplitude: 0.0152, phase_GMT: 328.5 },
  { name: '2SM6', amplitude: 0.0015, phase_GMT: 120.28 },
  { name: 'MSK6', amplitude: 0.0098, phase_GMT: 11.46 },
  // Seventh-diurnal
  { name: '3MK7', amplitude: 0.001, phase_GMT: 216.12 },
  { name: '3MO7', amplitude: 0.0029, phase_GMT: 290.28 },
  // Eighth-diurnal and higher
  { name: 'M8', amplitude: 0.0201, phase_GMT: 92.56 },
  { name: '3MS8', amplitude: 0.0306, phase_GMT: 129.29 },
  { name: '2MS8', amplitude: 0.0114, phase_GMT: 170.49 },
  { name: '2MSN8', amplitude: 0.0043, phase_GMT: 94.82 },
  { name: 'M10', amplitude: 0.0083, phase_GMT: 101.33 },
  // Long period
  { name: 'SA', amplitude: 0.0619, phase_GMT: 219.79 },
  { name: 'SSA', amplitude: 0.0262, phase_GMT: 114.75 },
  { name: 'MM', amplitude: 0.0182, phase_GMT: 185.25 },
  { name: 'MF', amplitude: 0.0146, phase_GMT: 187.17 },
  { name: 'MSF', amplitude: 0.0061, phase_GMT: 203.53 },
]

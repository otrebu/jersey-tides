import { useState, useEffect, useMemo } from 'react';

// ============================================================================
// JEAN MEEUS ALGORITHM - Accurate astronomical calculations
// Based on "Astronomical Algorithms" by Jean Meeus
// ============================================================================

const DEG_TO_RAD = Math.PI / 180;
const RAD_TO_DEG = 180 / Math.PI;

// Julian Date from JavaScript Date
function toJulianDate(date) {
  return date.getTime() / 86400000 + 2440587.5;
}

// Julian centuries from J2000.0
function toJulianCenturies(jd) {
  return (jd - 2451545.0) / 36525.0;
}

// Normalize angle to 0-360
function normalize360(angle) {
  return ((angle % 360) + 360) % 360;
}

// Calculate Moon Phase using Meeus algorithm
// Returns phase angle in degrees: 0=new, 90=first quarter, 180=full, 270=last quarter
function getMoonPhase(date) {
  const jd = toJulianDate(date);
  const T = toJulianCenturies(jd);
  const T2 = T * T;
  const T3 = T2 * T;
  const T4 = T3 * T;

  // Sun's mean longitude (degrees)
  const L0 = normalize360(280.4664567 + 360007.6982779 * T + 0.03032028 * T2);
  
  // Sun's mean anomaly (degrees)
  const M = normalize360(357.5291092 + 35999.0502909 * T - 0.0001536 * T2);
  const Mrad = M * DEG_TO_RAD;
  
  // Sun's equation of center
  const C = (1.9146 - 0.004817 * T - 0.000014 * T2) * Math.sin(Mrad)
          + (0.019993 - 0.000101 * T) * Math.sin(2 * Mrad)
          + 0.00029 * Math.sin(3 * Mrad);
  
  // Sun's true longitude
  const sunLong = normalize360(L0 + C);

  // Moon's mean longitude (degrees)
  const Lm = normalize360(218.3164477 + 481267.88123421 * T 
             - 0.0015786 * T2 + T3 / 538841 - T4 / 65194000);
  
  // Moon's mean anomaly (degrees)
  const Mm = normalize360(134.9633964 + 477198.8675055 * T
             + 0.0087414 * T2 + T3 / 69699 - T4 / 14712000);
  const Mmrad = Mm * DEG_TO_RAD;
  
  // Moon's mean elongation (degrees)
  const D = normalize360(297.8501921 + 445267.1114034 * T
            - 0.0018819 * T2 + T3 / 545868 - T4 / 113065000);
  const Drad = D * DEG_TO_RAD;
  
  // Moon's argument of latitude
  const F = normalize360(93.2720950 + 483202.0175233 * T
            - 0.0036539 * T2 - T3 / 3526000 + T4 / 863310000);
  const Frad = F * DEG_TO_RAD;

  // Corrections for Moon's longitude (simplified main terms)
  const moonCorrection = 
      6.289 * Math.sin(Mmrad)
    + 1.274 * Math.sin(2 * Drad - Mmrad)
    + 0.658 * Math.sin(2 * Drad)
    + 0.214 * Math.sin(2 * Mmrad)
    - 0.186 * Math.sin(Mrad)
    - 0.114 * Math.sin(2 * Frad)
    + 0.059 * Math.sin(2 * Drad - 2 * Mmrad)
    + 0.057 * Math.sin(2 * Drad - Mrad - Mmrad)
    + 0.053 * Math.sin(2 * Drad + Mmrad)
    + 0.046 * Math.sin(2 * Drad - Mrad)
    - 0.041 * Math.sin(Mrad - Mmrad)
    - 0.035 * Math.sin(Drad)
    - 0.030 * Math.sin(Mrad + Mmrad);

  const moonLong = normalize360(Lm + moonCorrection);
  
  // Phase angle: difference between moon and sun longitude
  const phaseAngle = normalize360(moonLong - sunLong);
  
  // Calculate illumination using phase angle
  const illumination = Math.round((1 - Math.cos(phaseAngle * DEG_TO_RAD)) / 2 * 100);
  
  // Determine phase name and emoji
  let name, emoji;
  if (phaseAngle < 22.5 || phaseAngle >= 337.5) {
    name = 'New Moon'; emoji = '🌑';
  } else if (phaseAngle < 67.5) {
    name = 'Waxing Crescent'; emoji = '🌒';
  } else if (phaseAngle < 112.5) {
    name = 'First Quarter'; emoji = '🌓';
  } else if (phaseAngle < 157.5) {
    name = 'Waxing Gibbous'; emoji = '🌔';
  } else if (phaseAngle < 202.5) {
    name = 'Full Moon'; emoji = '🌕';
  } else if (phaseAngle < 247.5) {
    name = 'Waning Gibbous'; emoji = '🌖';
  } else if (phaseAngle < 292.5) {
    name = 'Last Quarter'; emoji = '🌗';
  } else {
    name = 'Waning Crescent'; emoji = '🌘';
  }
  
  return { phaseAngle, name, emoji, illumination };
}

// ============================================================================
// SUNRISE/SUNSET - NOAA Solar Calculator Algorithm
// ============================================================================

const JERSEY_LAT = 49.2138;
const JERSEY_LON = -2.1358;

function getSunTimes(date, lat = JERSEY_LAT, lon = JERSEY_LON) {
  const year = date.getFullYear();
  const month = date.getMonth() + 1;
  const day = date.getDate();
  
  // Day of year
  const N1 = Math.floor(275 * month / 9);
  const N2 = Math.floor((month + 9) / 12);
  const N3 = (1 + Math.floor((year - 4 * Math.floor(year / 4) + 2) / 3));
  const N = N1 - (N2 * N3) + day - 30;
  
  const lngHour = lon / 15;
  
  const calcSunTime = (rising) => {
    const t = N + ((rising ? 6 : 18) - lngHour) / 24;
    const M = (0.9856 * t) - 3.289;
    let L = M + (1.916 * Math.sin(M * DEG_TO_RAD)) + (0.020 * Math.sin(2 * M * DEG_TO_RAD)) + 282.634;
    L = normalize360(L);
    
    let RA = Math.atan(0.91764 * Math.tan(L * DEG_TO_RAD)) * RAD_TO_DEG;
    RA = normalize360(RA);
    const Lquadrant = Math.floor(L / 90) * 90;
    const RAquadrant = Math.floor(RA / 90) * 90;
    RA = RA + (Lquadrant - RAquadrant);
    RA = RA / 15;
    
    const sinDec = 0.39782 * Math.sin(L * DEG_TO_RAD);
    const cosDec = Math.cos(Math.asin(sinDec));
    const zenith = 90.833;
    const cosH = (Math.cos(zenith * DEG_TO_RAD) - (sinDec * Math.sin(lat * DEG_TO_RAD))) / (cosDec * Math.cos(lat * DEG_TO_RAD));
    
    if (cosH > 1 || cosH < -1) return null;
    
    let H = rising ? 360 - Math.acos(cosH) * RAD_TO_DEG : Math.acos(cosH) * RAD_TO_DEG;
    H = H / 15;
    
    let T = H + RA - (0.06571 * t) - 6.622;
    let UT = T - lngHour;
    UT = ((UT % 24) + 24) % 24;
    
    const hours = Math.floor(UT);
    const minutes = Math.round((UT - hours) * 60);
    return new Date(year, month - 1, day, hours, minutes, 0);
  };
  
  const sunrise = calcSunTime(true);
  const sunset = calcSunTime(false);
  
  let dayLength = null;
  if (sunrise && sunset) {
    const diff = sunset.getTime() - sunrise.getTime();
    dayLength = {
      hours: Math.floor(diff / (1000 * 60 * 60)),
      minutes: Math.round((diff % (1000 * 60 * 60)) / (1000 * 60))
    };
  }
  
  return { sunrise, sunset, dayLength };
}

// ============================================================================
// TIDE PREDICTION - Harmonic Analysis
// ============================================================================

const d2r = Math.PI / 180;
const r2d = 180 / Math.PI;

const sexagesimalToDecimal = (deg, min = 0, sec = 0) => deg + min / 60 + sec / 3600;

const coefficients = {
  terrestrialObliquity: [sexagesimalToDecimal(23, 26, 21.448), -sexagesimalToDecimal(0, 0, 4680.93), -sexagesimalToDecimal(0, 0, 1.55), sexagesimalToDecimal(0, 0, 1999.25), -sexagesimalToDecimal(0, 0, 51.38), -sexagesimalToDecimal(0, 0, 249.67), -sexagesimalToDecimal(0, 0, 39.05), sexagesimalToDecimal(0, 0, 7.12), sexagesimalToDecimal(0, 0, 27.87), sexagesimalToDecimal(0, 0, 5.79), sexagesimalToDecimal(0, 0, 2.45)].map((n, i) => n * Math.pow(0.01, i)),
  solarPerigee: [-77.0627, 1.7192, 0.00046, 0.0000005],
  solarLongitude: [280.4665, 36000.7698, 0.0003],
  lunarInclination: [5.145],
  lunarLongitude: [218.3165, 481267.8813, -0.0013, 1/538841, -1/65194000],
  lunarNode: [125.0445, -1934.1362, 0.0021, 1/467410, -1/60616000],
  lunarPerigee: [83.3532, 4069.0137, -0.0103, -1/80053, 1/18999000]
};

const polynomial = (c, x) => c.reduce((s, v, i) => s + v * Math.pow(x, i), 0);
const derivPolynomial = (c, x) => c.reduce((s, v, i) => s + v * i * Math.pow(x, i - 1), 0);
const JD = (t) => { let Y = t.getFullYear(), M = t.getMonth() + 1; const D = t.getDate() + t.getHours()/24 + t.getMinutes()/1440 + t.getSeconds()/86400; if (M <= 2) { Y--; M += 12; } const A = Math.floor(Y/100), B = 2 - A + Math.floor(A/4); return Math.floor(365.25*(Y+4716)) + Math.floor(30.6001*(M+1)) + D + B - 1524.5; };
const T_tide = (t) => (JD(t) - 2451545) / 36525;
const mod = (a, b) => ((a % b) + b) % b;

const _I = (N, i, o) => { N *= d2r; i *= d2r; o *= d2r; return r2d * Math.acos(Math.cos(i)*Math.cos(o) - Math.sin(i)*Math.sin(o)*Math.cos(N)); };
const _xi = (N, i, o) => { N *= d2r; i *= d2r; o *= d2r; let e1 = Math.atan(Math.cos(0.5*(o-i))/Math.cos(0.5*(o+i))*Math.tan(0.5*N)), e2 = Math.atan(Math.sin(0.5*(o-i))/Math.sin(0.5*(o+i))*Math.tan(0.5*N)); return -(e1 - 0.5*N + e2 - 0.5*N) * r2d; };
const _nu = (N, i, o) => { N *= d2r; i *= d2r; o *= d2r; let e1 = Math.atan(Math.cos(0.5*(o-i))/Math.cos(0.5*(o+i))*Math.tan(0.5*N)), e2 = Math.atan(Math.sin(0.5*(o-i))/Math.sin(0.5*(o+i))*Math.tan(0.5*N)); return (e1 - 0.5*N - e2 + 0.5*N) * r2d; };
const _nup = (N, i, o) => { const I = _I(N,i,o)*d2r, nu = _nu(N,i,o)*d2r; return r2d*Math.atan(Math.sin(2*I)*Math.sin(nu)/(Math.sin(2*I)*Math.cos(nu)+0.3347)); };
const _nupp = (N, i, o) => { const I = _I(N,i,o)*d2r, nu = _nu(N,i,o)*d2r; return r2d*0.5*Math.atan(Math.sin(I)**2*Math.sin(2*nu)/(Math.sin(I)**2*Math.cos(2*nu)+0.0727)); };

const astro = (time) => {
  const result = {}, polys = { s: coefficients.lunarLongitude, h: coefficients.solarLongitude, p: coefficients.lunarPerigee, N: coefficients.lunarNode, pp: coefficients.solarPerigee, "90": [90], omega: coefficients.terrestrialObliquity, i: coefficients.lunarInclination };
  const Tv = T_tide(time), dT = 1/(24*365.25*100);
  for (const n in polys) result[n] = { value: mod(polynomial(polys[n], Tv), 360), speed: derivPolynomial(polys[n], Tv) * dT };
  const fns = { I: _I, xi: _xi, nu: _nu, nup: _nup, nupp: _nupp };
  for (const n in fns) result[n] = { value: mod(fns[n](result.N.value, result.i.value, result.omega.value), 360), speed: null };
  const hour = { value: (JD(time) - Math.floor(JD(time))) * 360, speed: 15 };
  result["T+h-s"] = { value: hour.value + result.h.value - result.s.value, speed: hour.speed + result.h.speed - result.s.speed };
  result.P = { value: result.p.value - result.xi.value % 360, speed: null };
  return result;
};

const corrections = {
  fUnity: () => 1, fMm: (a) => { const o = d2r*a.omega.value, i = d2r*a.i.value, I = d2r*a.I.value; return (2/3-Math.sin(I)**2)/((2/3-Math.sin(o)**2)*(1-1.5*Math.sin(i)**2)); },
  fMf: (a) => { const o = d2r*a.omega.value, i = d2r*a.i.value, I = d2r*a.I.value; return Math.sin(I)**2/(Math.sin(o)**2*Math.cos(0.5*i)**4); },
  fO1: (a) => { const o = d2r*a.omega.value, i = d2r*a.i.value, I = d2r*a.I.value; return Math.sin(I)*Math.cos(0.5*I)**2/(Math.sin(o)*Math.cos(0.5*o)**2*Math.cos(0.5*i)**4); },
  fJ1: (a) => { const o = d2r*a.omega.value, i = d2r*a.i.value, I = d2r*a.I.value; return Math.sin(2*I)/(Math.sin(2*o)*(1-1.5*Math.sin(i)**2)); },
  fM2: (a) => { const o = d2r*a.omega.value, i = d2r*a.i.value, I = d2r*a.I.value; return Math.cos(0.5*I)**4/(Math.cos(0.5*o)**4*Math.cos(0.5*i)**4); },
  fK1: (a) => { const o = d2r*a.omega.value, i = d2r*a.i.value, I = d2r*a.I.value, nu = d2r*a.nu.value; return Math.sqrt(0.2523*Math.sin(2*I)**2+0.1689*Math.sin(2*I)*Math.cos(nu)+0.0283)/(0.5023*(Math.sin(2*o)*(1-1.5*Math.sin(i)**2))+0.1681); },
  fK2: (a) => { const o = d2r*a.omega.value, i = d2r*a.i.value, I = d2r*a.I.value, nu = d2r*a.nu.value; return Math.sqrt(0.2523*Math.sin(I)**4+0.0367*Math.sin(I)**2*Math.cos(2*nu)+0.0013)/(0.5023*(Math.sin(o)**2*(1-1.5*Math.sin(i)**2))+0.0365); },
  uZero: () => 0, uMf: (a) => -2*a.xi.value, uO1: (a) => 2*a.xi.value - a.nu.value, uJ1: (a) => -a.nu.value, uM2: (a) => 2*a.xi.value - 2*a.nu.value, uK1: (a) => -a.nup.value, uK2: (a) => -2*a.nupp.value
};

const dotArr = (a, b) => a.reduce((s, v, i) => s + v * b[i], 0);
const astronum = (a) => [a["T+h-s"], a.s, a.h, a.p, a.N, a.pp, a["90"]];
const constFactory = (name, coef, u, f) => ({ name, coef, value: (a) => dotArr(coef, astronum(a).map(x=>x.value)), speed: (a) => dotArr(coef, astronum(a).map(x=>x.speed)), u: u||corrections.uZero, f: f||corrections.fUnity });

const constituents = {
  Z0: constFactory("Z0", [0,0,0,0,0,0,0]), M2: constFactory("M2", [2,0,0,0,0,0,0], corrections.uM2, corrections.fM2),
  S2: constFactory("S2", [2,2,-2,0,0,0,0]), N2: constFactory("N2", [2,-1,0,1,0,0,0], corrections.uM2, corrections.fM2),
  K2: constFactory("K2", [2,2,0,0,0,0,0], corrections.uK2, corrections.fK2), K1: constFactory("K1", [1,1,0,0,0,0,-1], corrections.uK1, corrections.fK1),
  O1: constFactory("O1", [1,-1,0,0,0,0,1], corrections.uO1, corrections.fO1), M4: constFactory("M4", [4,0,0,0,0,0,0], corrections.uM2, (a)=>corrections.fM2(a)**2),
  MS4: constFactory("MS4", [4,2,-2,0,0,0,0], corrections.uM2, corrections.fM2)
};

const DATUM = 6.0036;
const ST_HELIER = [
  { name: 'M2', amplitude: 3.3467, phase: 182.48 }, { name: 'S2', amplitude: 1.2994, phase: 232.24 },
  { name: 'N2', amplitude: 0.6576, phase: 165.59 }, { name: 'K2', amplitude: 0.3715, phase: 230.12 },
  { name: 'K1', amplitude: 0.0928, phase: 97.78 }, { name: 'O1', amplitude: 0.0798, phase: 346.61 },
  { name: 'M4', amplitude: 0.1926, phase: 300.81 }, { name: 'MS4', amplitude: 0.1451, phase: 357.81 }
];

function getTideLevel(time) {
  const a = astro(time);
  return DATUM + ST_HELIER.reduce((sum, c) => {
    const con = constituents[c.name];
    if (!con) return sum;
    const V = con.value(a) * d2r, u = con.u(a) * d2r, f = con.f(a), phase = c.phase * d2r;
    return sum + c.amplitude * f * Math.cos(V + u - phase);
  }, 0);
}

function getDayExtremes(date) {
  const start = new Date(date); start.setHours(0, 0, 0, 0);
  const extremes = [], step = 600000;
  let prev = getTideLevel(start), prevPrev = prev, prevTime = start;
  
  for (let t = start.getTime() + step; t <= start.getTime() + 86400000; t += step) {
    const time = new Date(t), level = getTideLevel(time);
    if (prev > prevPrev && prev > level) extremes.push({ time: prevTime, height: prev, type: 'high' });
    if (prev < prevPrev && prev < level) extremes.push({ time: prevTime, height: prev, type: 'low' });
    prevPrev = prev; prev = level; prevTime = time;
  }
  return extremes;
}

function getCurrentLevel(now = new Date()) {
  const height = getTideLevel(now);
  const start = new Date(now); start.setHours(0, 0, 0, 0);
  const end = new Date(now); end.setDate(end.getDate() + 1);
  const extremes = getDayExtremes(start).concat(getDayExtremes(end));
  const next = extremes.find(e => e.time > now);
  return { height, rising: next ? next.type === 'high' : false, nextExtreme: next };
}

// ============================================================================
// SVG ICONS
// ============================================================================

const SunIcon = ({ color = '#f59e0b', size = 20 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <circle cx="12" cy="12" r="5" fill={color} />
    <g stroke={color} strokeWidth="2" strokeLinecap="round">
      <line x1="12" y1="1" x2="12" y2="4" /><line x1="12" y1="20" x2="12" y2="23" />
      <line x1="1" y1="12" x2="4" y2="12" /><line x1="20" y1="12" x2="23" y2="12" />
      <line x1="4.22" y1="4.22" x2="6.34" y2="6.34" /><line x1="17.66" y1="17.66" x2="19.78" y2="19.78" />
      <line x1="4.22" y1="19.78" x2="6.34" y2="17.66" /><line x1="17.66" y1="6.34" x2="19.78" y2="4.22" />
    </g>
  </svg>
);

const SunriseIcon = ({ color = '#f59e0b', size = 20 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <line x1="1" y1="18" x2="23" y2="18" stroke={color} strokeWidth="2" strokeLinecap="round" />
    <circle cx="12" cy="14" r="4" fill={color} />
    <path d="M12 1L8 5h3v3h2V5h3L12 1z" fill={color} />
  </svg>
);

const SunsetIcon = ({ color = '#f59e0b', size = 20 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <line x1="1" y1="18" x2="23" y2="18" stroke={color} strokeWidth="2" strokeLinecap="round" />
    <circle cx="12" cy="16" r="4" fill={color} opacity="0.6" />
    <path d="M12 8L8 4h3V1h2v3h3L12 8z" fill={color} opacity="0.7" />
  </svg>
);

// ============================================================================
// THEMES
// ============================================================================

const THEMES = {
  brutalist: { name: "Brutalist", bg: "#f8f8f8", cardBg: "#fff", cardBorder: "2px solid #111", headerBg: "#f0f0f0", headerText: "#111", text: "#111", textMuted: "#555", accent: "#111", currentBg: "#111", currentText: "#fff", currentMuted: "#aaa", highBg: "#111", highText: "#fff", lowBg: "#fff", lowText: "#111", lowBorder: "#111", selectedBg: "#111", selectedText: "#fff", todayBorder: "#111", curveStroke: "#111", curveDot: "#111", curveDotLow: "#fff", barBg: "#e5e5e5", barFill: "#111", sunMoonBg: "#f5f5f5", sunColor: "#d97706", fontFamily: '"SF Mono", Consolas, monospace', borderRadius: "0", shadow: "none" },
  eighties: { name: "80s Aerobics", bg: "linear-gradient(135deg, #ff6b9d 0%, #c44dff 50%, #44d9e8 100%)", cardBg: "#fff", cardBorder: "3px solid #222", headerBg: "#222", headerText: "#ffeb3b", text: "#222", textMuted: "#555", accent: "#e91e8c", currentBg: "linear-gradient(135deg, #ffeb3b 0%, #ff6b9d 100%)", currentText: "#222", currentMuted: "#555", highBg: "#e91e8c", highText: "#fff", lowBg: "#00b4d8", lowText: "#fff", lowBorder: "none", selectedBg: "#9d4edd", selectedText: "#fff", todayBorder: "#ffeb3b", curveStroke: "#9d4edd", curveDot: "#e91e8c", curveDotLow: "#00b4d8", barBg: "#ffe0ec", barFill: "linear-gradient(90deg, #e91e8c, #9d4edd)", sunMoonBg: "#fff5cc", sunColor: "#ff6b00", fontFamily: '"Arial Black", sans-serif', borderRadius: "0", shadow: "3px 3px 0 #222" },
  nautical: { name: "Maritime", bg: "#e8e4db", cardBg: "#fffdf8", cardBorder: "2px solid #1e3a5f", headerBg: "#1e3a5f", headerText: "#f5f1e8", text: "#1e3a5f", textMuted: "#4a6a8a", accent: "#c9a227", currentBg: "#1e3a5f", currentText: "#f5f1e8", currentMuted: "#a0b8d0", highBg: "#1e3a5f", highText: "#f5f1e8", lowBg: "#fffdf8", lowText: "#1e3a5f", lowBorder: "#1e3a5f", selectedBg: "#1e3a5f", selectedText: "#f5f1e8", todayBorder: "#c9a227", curveStroke: "#1e3a5f", curveDot: "#c9a227", curveDotLow: "#fffdf8", barBg: "#d4d0c7", barFill: "#1e3a5f", sunMoonBg: "#f0ece3", sunColor: "#c9a227", fontFamily: '"Palatino", Georgia, serif', borderRadius: "3px", shadow: "0 2px 6px rgba(30,58,95,0.12)" },
  zen: { name: "Zen Wave", bg: "#f8f9fa", cardBg: "#fff", cardBorder: "1px solid #ced4da", headerBg: "#fff", headerText: "#2b4acb", text: "#212529", textMuted: "#5c636a", accent: "#2b4acb", currentBg: "linear-gradient(135deg, #2b4acb 0%, #5c7cfa 100%)", currentText: "#fff", currentMuted: "#c5d0f5", highBg: "#2b4acb", highText: "#fff", lowBg: "#fff", lowText: "#2b4acb", lowBorder: "#2b4acb", selectedBg: "#2b4acb", selectedText: "#fff", todayBorder: "#5c7cfa", curveStroke: "#2b4acb", curveDot: "#5c7cfa", curveDotLow: "#fff", barBg: "#e9ecef", barFill: "linear-gradient(90deg, #2b4acb, #5c7cfa)", sunMoonBg: "#f0f2ff", sunColor: "#f59e0b", fontFamily: '"Hiragino Mincho ProN", Georgia, serif', borderRadius: "2px", shadow: "none" },
  surf: { name: "70s Surf", bg: "linear-gradient(180deg, #f4a261 0%, #e76f51 100%)", cardBg: "#fef3e2", cardBorder: "3px solid #264653", headerBg: "#264653", headerText: "#fef3e2", text: "#264653", textMuted: "#4a6670", accent: "#e76f51", currentBg: "#264653", currentText: "#fef3e2", currentMuted: "#a0b8c0", highBg: "#e76f51", highText: "#fff", lowBg: "#fef3e2", lowText: "#264653", lowBorder: "#264653", selectedBg: "#264653", selectedText: "#fef3e2", todayBorder: "#f4a261", curveStroke: "#e76f51", curveDot: "#f4a261", curveDotLow: "#fef3e2", barBg: "#f5dfc5", barFill: "linear-gradient(90deg, #f4a261, #e76f51)", sunMoonBg: "#fff8f0", sunColor: "#e76f51", fontFamily: '"Rockwell", Georgia, serif', borderRadius: "8px", shadow: "2px 2px 0 #264653" },
  synthwave: { name: "Synthwave", bg: "linear-gradient(180deg, #1a1a2e 0%, #16213e 50%, #0f0f23 100%)", cardBg: "rgba(26, 26, 46, 0.95)", cardBorder: "2px solid #e040fb", headerBg: "rgba(26, 26, 46, 0.8)", headerText: "#00e5ff", text: "#f0f0f0", textMuted: "#a0a0c0", accent: "#e040fb", currentBg: "linear-gradient(135deg, #e040fb 0%, #00e5ff 100%)", currentText: "#0f0f23", currentMuted: "#333", highBg: "#e040fb", highText: "#fff", lowBg: "transparent", lowText: "#00e5ff", lowBorder: "#00e5ff", selectedBg: "#e040fb", selectedText: "#fff", todayBorder: "#00e5ff", curveStroke: "#e040fb", curveDot: "#00e5ff", curveDotLow: "#1a1a2e", barBg: "rgba(255,255,255,0.1)", barFill: "linear-gradient(90deg, #e040fb, #00e5ff)", sunMoonBg: "rgba(224,64,251,0.1)", sunColor: "#ffeb3b", fontFamily: '"Consolas", monospace', borderRadius: "0", shadow: "0 0 15px rgba(224,64,251,0.4)" }
};

// ============================================================================
// TIDE CURVE
// ============================================================================

function TideCurve({ extremes, currentTime, isToday, theme, sunTimes }) {
  if (extremes.length < 2) return null;
  const t = THEMES[theme], width = 340, height = 80;
  const pad = { top: 16, bottom: 18, left: 30, right: 8 };
  const cw = width - pad.left - pad.right, ch = height - pad.top - pad.bottom;

  const tidePoints = extremes.map(e => ({ hour: e.time.getHours() + e.time.getMinutes()/60, height: e.height, type: e.type }));
  const pts = [];
  if (tidePoints[0].hour > 0) pts.push({ hour: 0, height: (tidePoints[0].height + tidePoints[1].height) / 2 });
  for (let i = 0; i < tidePoints.length - 1; i++) {
    const t1 = tidePoints[i], t2 = tidePoints[i + 1];
    pts.push({ hour: t1.hour, height: t1.height });
    for (let j = 1; j < 10; j++) {
      const p = j / 10, h = t1.hour + (t2.hour - t1.hour) * p;
      pts.push({ hour: h, height: t1.height + (t2.height - t1.height) * (1 - Math.cos(p * Math.PI)) / 2 });
    }
  }
  const last = tidePoints[tidePoints.length - 1];
  pts.push({ hour: last.hour, height: last.height });
  if (last.hour < 24) pts.push({ hour: 24, height: (last.height + tidePoints[tidePoints.length - 2].height) / 2 });

  const minH = Math.min(...pts.map(p => p.height)) - 0.5, maxH = Math.max(...pts.map(p => p.height)) + 0.5, range = maxH - minH;
  const pathD = pts.map((p, i) => `${i === 0 ? 'M' : 'L'} ${(pad.left + (p.hour / 24) * cw).toFixed(1)} ${(pad.top + ch - ((p.height - minH) / range) * ch).toFixed(1)}`).join(' ');
  
  const curHour = currentTime.getHours() + currentTime.getMinutes() / 60;
  const curX = pad.left + (curHour / 24) * cw;
  const srX = sunTimes.sunrise ? pad.left + ((sunTimes.sunrise.getHours() + sunTimes.sunrise.getMinutes() / 60) / 24) * cw : null;
  const ssX = sunTimes.sunset ? pad.left + ((sunTimes.sunset.getHours() + sunTimes.sunset.getMinutes() / 60) / 24) * cw : null;

  return (
    <svg width={width} height={height} style={{ display: 'block', margin: '0 auto' }}>
      {srX && <rect x={pad.left} y={pad.top} width={srX - pad.left} height={ch} fill={t.text} opacity="0.06" />}
      {ssX && <rect x={ssX} y={pad.top} width={pad.left + cw - ssX} height={ch} fill={t.text} opacity="0.06" />}
      {[0, 6, 12, 18, 24].map(h => (<g key={h}><line x1={pad.left + (h/24)*cw} y1={pad.top} x2={pad.left + (h/24)*cw} y2={pad.top + ch} stroke={t.textMuted} strokeWidth="1" opacity="0.3" /><text x={pad.left + (h/24)*cw} y={height - 3} textAnchor="middle" fontSize="9" fill={t.textMuted} fontFamily={t.fontFamily}>{String(h % 24).padStart(2, '0')}</text></g>))}
      {srX && <><line x1={srX} y1={pad.top} x2={srX} y2={pad.top + ch} stroke={t.sunColor} strokeWidth="1.5" opacity="0.7" /><g transform={`translate(${srX - 6}, ${pad.top - 14})`}><SunriseIcon color={t.sunColor} size={12} /></g></>}
      {ssX && <><line x1={ssX} y1={pad.top} x2={ssX} y2={pad.top + ch} stroke={t.sunColor} strokeWidth="1.5" opacity="0.7" /><g transform={`translate(${ssX - 6}, ${pad.top - 14})`}><SunsetIcon color={t.sunColor} size={12} /></g></>}
      <text x={pad.left - 4} y={pad.top + 4} textAnchor="end" fontSize="9" fill={t.textMuted} fontFamily={t.fontFamily}>{maxH.toFixed(0)}m</text>
      <text x={pad.left - 4} y={pad.top + ch} textAnchor="end" fontSize="9" fill={t.textMuted} fontFamily={t.fontFamily}>{minH.toFixed(0)}m</text>
      <path d={pathD} fill="none" stroke={t.curveStroke} strokeWidth="2.5" />
      {tidePoints.map((tp, i) => { const x = pad.left + (tp.hour / 24) * cw, y = pad.top + ch - ((tp.height - minH) / range) * ch; return <circle key={i} cx={x} cy={y} r="4.5" fill={tp.type === 'high' ? t.curveDot : t.curveDotLow} stroke={t.curveStroke} strokeWidth="2" />; })}
      {isToday && <line x1={curX} y1={pad.top} x2={curX} y2={pad.top + ch} stroke={t.accent} strokeWidth="2" strokeDasharray="4,3" />}
    </svg>
  );
}

// ============================================================================
// MAIN APP
// ============================================================================

const DAYS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

export default function App() {
  const [theme, setTheme] = useState('brutalist');
  const [currentDate, setCurrentDate] = useState(new Date());
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [currentTime, setCurrentTime] = useState(new Date());
  const t = THEMES[theme];

  useEffect(() => { const i = setInterval(() => setCurrentTime(new Date()), 60000); return () => clearInterval(i); }, []);

  const extremes = useMemo(() => getDayExtremes(selectedDate), [selectedDate]);
  const isToday = selectedDate.toDateString() === new Date().toDateString();
  const currentLevel = useMemo(() => isToday ? getCurrentLevel(currentTime) : null, [isToday, currentTime]);
  const sunTimes = useMemo(() => getSunTimes(selectedDate), [selectedDate]);
  const moonPhase = useMemo(() => getMoonPhase(selectedDate), [selectedDate]);
  
  const calendarMoons = useMemo(() => {
    const m = {}, year = currentDate.getFullYear(), month = currentDate.getMonth();
    for (let d = 1; d <= new Date(year, month + 1, 0).getDate(); d++) m[d] = getMoonPhase(new Date(year, month, d));
    return m;
  }, [currentDate]);

  const calendarData = useMemo(() => {
    const year = currentDate.getFullYear(), month = currentDate.getMonth();
    const first = new Date(year, month, 1), last = new Date(year, month + 1, 0);
    const pad = (first.getDay() + 6) % 7, days = [];
    for (let i = 0; i < pad; i++) days.push(null);
    for (let i = 1; i <= last.getDate(); i++) days.push(new Date(year, month, i));
    return days;
  }, [currentDate]);

  const navMonth = (d) => setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() + d, 1));
  const isSel = (d) => d && d.toDateString() === selectedDate.toDateString();
  const isTodayD = (d) => d && d.toDateString() === new Date().toDateString();
  const fmtTime = (d) => d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
  const fmtDate = () => selectedDate.toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' }).toUpperCase();

  const events = useMemo(() => {
    const e = extremes.map(x => ({ ...x }));
    if (sunTimes.sunrise) e.push({ type: 'sunrise', time: sunTimes.sunrise });
    if (sunTimes.sunset) e.push({ type: 'sunset', time: sunTimes.sunset });
    return e.sort((a, b) => a.time - b.time);
  }, [extremes, sunTimes]);

  return (
    <div style={{ minHeight: '100vh', background: t.bg, padding: '1rem 0.75rem', fontFamily: t.fontFamily, color: t.text }}>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <header style={{ textAlign: 'center', marginBottom: '0.5rem' }}>
          <h1 style={{ fontSize: '1.6rem', fontWeight: 900, letterSpacing: '0.12em', margin: 0, color: theme === 'synthwave' ? '#00e5ff' : t.text, borderBottom: theme === 'brutalist' ? '3px solid #111' : 'none', paddingBottom: '0.3rem' }}>JERSEY TIDES</h1>
          <div style={{ fontSize: '0.55rem', color: t.textMuted, letterSpacing: '0.08em', marginTop: '0.3rem' }}>ST. HELIER · TIDES · SUN · MOON</div>
        </header>

        <div style={{ width: '100%', maxWidth: '360px', marginBottom: '0.5rem', padding: '0.7rem 0.8rem', border: t.cardBorder, borderRadius: t.borderRadius, background: t.currentBg, color: t.currentText, boxShadow: t.shadow }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: '0.6rem' }}>
            <span style={{ fontSize: '0.55rem', fontWeight: 700, letterSpacing: '0.1em' }}>{isToday ? 'NOW' : 'VIEWING'}</span>
            <span style={{ fontSize: '1.4rem', fontWeight: 900 }}>{isToday && currentLevel ? `${currentLevel.height.toFixed(1)}m` : selectedDate.toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })}</span>
            <span style={{ fontSize: '0.6rem', fontWeight: 700 }}>{isToday && currentLevel ? (currentLevel.rising ? '↑ RISING' : '↓ FALLING') : selectedDate.getFullYear()}</span>
            <span style={{ fontSize: '1.2rem', marginLeft: 'auto' }}>{moonPhase.emoji}</span>
          </div>
          <div style={{ fontSize: '0.55rem', color: t.currentMuted, marginTop: '0.25rem' }}>
            {isToday && currentLevel?.nextExtreme ? `Next ${currentLevel.nextExtreme.type} at ${fmtTime(currentLevel.nextExtreme.time)}` : `${extremes.length} tides · ${moonPhase.name}`}
          </div>
        </div>

        <div style={{ width: '100%', maxWidth: '360px', border: t.cardBorder, borderRadius: t.borderRadius, background: t.cardBg, overflow: 'hidden', boxShadow: t.shadow }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0.45rem 0.6rem', background: t.headerBg, color: t.headerText, borderBottom: t.cardBorder }}>
            <button onClick={() => navMonth(-1)} style={{ background: 'none', border: 'none', color: 'inherit', fontSize: '0.9rem', cursor: 'pointer', padding: '0.2rem 0.4rem', fontFamily: t.fontFamily }}>◀</button>
            <span style={{ fontSize: '0.7rem', fontWeight: 700, letterSpacing: '0.1em' }}>{MONTHS[currentDate.getMonth()]} {currentDate.getFullYear()}</span>
            <button onClick={() => navMonth(1)} style={{ background: 'none', border: 'none', color: 'inherit', fontSize: '0.9rem', cursor: 'pointer', padding: '0.2rem 0.4rem', fontFamily: t.fontFamily }}>▶</button>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', borderBottom: `1px solid ${t.textMuted}44` }}>
            {DAYS.map((d, i) => <div key={i} style={{ textAlign: 'center', padding: '0.35rem', fontSize: '0.6rem', fontWeight: 700, color: t.textMuted }}>{d}</div>)}
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)' }}>
            {calendarData.map((date, i) => {
              const day = date?.getDate(), phase = day ? calendarMoons[day] : null;
              return (<button key={i} onClick={() => date && setSelectedDate(date)} disabled={!date} style={{ aspectRatio: '1', border: 'none', background: isSel(date) ? t.selectedBg : (date ? t.cardBg : `${t.textMuted}15`), color: isSel(date) ? t.selectedText : t.text, fontSize: '0.7rem', fontFamily: t.fontFamily, fontWeight: isSel(date) || isTodayD(date) ? 700 : 400, cursor: date ? 'pointer' : 'default', boxShadow: isTodayD(date) && !isSel(date) ? `inset 0 0 0 2px ${t.todayBorder}` : 'none', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '1px', padding: '2px' }}>
                <span>{day || ''}</span>
                {phase && <span style={{ fontSize: '0.55rem', opacity: isSel(date) ? 1 : 0.6, lineHeight: 1 }}>{phase.emoji}</span>}
              </button>);
            })}
          </div>
        </div>

        <div style={{ width: '100%', maxWidth: '360px', marginTop: '0.5rem', border: t.cardBorder, borderRadius: t.borderRadius, background: t.cardBg, overflow: 'hidden', boxShadow: t.shadow }}>
          <div style={{ padding: '0.45rem 0.6rem', background: t.headerBg, color: t.headerText, display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: t.cardBorder }}>
            <div style={{ fontSize: '0.6rem', fontWeight: 700, letterSpacing: '0.04em' }}>{fmtDate()}</div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0.45rem 0.6rem', background: t.sunMoonBg, borderBottom: `1px solid ${t.textMuted}33` }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
              <SunIcon color={t.sunColor} size={16} />
              <div><div style={{ fontSize: '0.5rem', color: t.textMuted, letterSpacing: '0.05em' }}>DAYLIGHT</div><div style={{ fontSize: '0.7rem', fontWeight: 700, color: t.sunColor }}>{sunTimes.dayLength ? `${sunTimes.dayLength.hours}h ${sunTimes.dayLength.minutes}m` : '--'}</div></div>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
              <span style={{ fontSize: '1.1rem' }}>{moonPhase.emoji}</span>
              <div style={{ textAlign: 'right' }}><div style={{ fontSize: '0.5rem', color: t.textMuted, letterSpacing: '0.05em' }}>MOON</div><div style={{ fontSize: '0.7rem', fontWeight: 700 }}>{moonPhase.name}</div></div>
            </div>
          </div>
          <div style={{ padding: '0.5rem', borderBottom: `1px solid ${t.textMuted}33` }}>
            <TideCurve extremes={extremes} currentTime={currentTime} isToday={isToday} theme={theme} sunTimes={sunTimes} />
          </div>
          <div style={{ padding: '0.2rem 0' }}>
            {events.map((e, i) => {
              const isSun = e.type === 'sunrise' || e.type === 'sunset';
              return (<div key={i} style={{ display: 'grid', gridTemplateColumns: '44px 55px 1fr', alignItems: 'center', padding: '0.5rem 0.6rem', gap: '0.5rem', borderBottom: i < events.length - 1 ? `1px solid ${t.textMuted}22` : 'none', background: isSun ? t.sunMoonBg : 'transparent' }}>
                <span style={{ fontSize: '0.55rem', fontWeight: 700, padding: '0.12rem 0', width: '36px', textAlign: 'center', boxSizing: 'border-box', display: 'inline-block', background: isSun ? t.sunMoonBg : (e.type === 'high' ? t.highBg : t.lowBg), color: isSun ? t.sunColor : (e.type === 'high' ? t.highText : t.lowText), border: isSun ? `2px solid ${t.sunColor}` : (e.type === 'low' && t.lowBorder !== 'none' ? `2px solid ${t.lowBorder}` : '2px solid transparent'), borderRadius: t.borderRadius }}>{isSun ? (e.type === 'sunrise' ? 'RISE' : 'SET') : e.type.toUpperCase()}</span>
                <span style={{ fontSize: '0.95rem', fontWeight: 700 }}>{fmtTime(e.time)}</span>
                {isSun ? (<div style={{ fontSize: '0.75rem', color: t.sunColor, fontWeight: 600, display: 'flex', alignItems: 'center', gap: '0.35rem' }}>{e.type === 'sunrise' ? <SunriseIcon color={t.sunColor} size={18} /> : <SunsetIcon color={t.sunColor} size={18} />}{e.type === 'sunrise' ? 'Sunrise' : 'Sunset'}</div>) : (<div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}><span style={{ fontSize: '0.8rem', color: t.textMuted, minWidth: '38px' }}>{e.height.toFixed(1)}m</span><div style={{ flex: 1, height: '6px', background: t.barBg, borderRadius: t.borderRadius, overflow: 'hidden' }}><div style={{ width: `${(e.height / 12) * 100}%`, height: '100%', background: t.barFill, borderRadius: t.borderRadius }} /></div></div>)}
              </div>);
            })}
          </div>
          <div style={{ padding: '0.4rem 0.6rem', fontSize: '0.5rem', color: t.textMuted, textAlign: 'center', borderTop: `1px solid ${t.textMuted}22` }}>CALCULATED · ±10 MIN TYPICAL ACCURACY</div>
        </div>

        <footer style={{ marginTop: '0.5rem', fontSize: '0.5rem', color: t.textMuted, textAlign: 'center' }}>49.21°N · 2.14°W · DATUM: LAT</footer>

        <div style={{ marginTop: '1.5rem', paddingTop: '0.8rem', borderTop: `1px solid ${t.textMuted}33`, width: '100%', maxWidth: '360px' }}>
          <div style={{ fontSize: '0.45rem', color: t.textMuted, textAlign: 'center', marginBottom: '0.4rem', letterSpacing: '0.1em' }}>THEME</div>
          <div style={{ display: 'flex', gap: '0.3rem', flexWrap: 'wrap', justifyContent: 'center' }}>
            {Object.entries(THEMES).map(([k, v]) => (<button key={k} onClick={() => setTheme(k)} style={{ padding: '0.25rem 0.5rem', border: theme === k ? `1px solid ${t.accent}` : `1px solid ${t.textMuted}55`, borderRadius: t.borderRadius, background: theme === k ? t.selectedBg : 'transparent', color: theme === k ? t.selectedText : t.textMuted, fontFamily: t.fontFamily, fontSize: '0.5rem', cursor: 'pointer', opacity: theme === k ? 1 : 0.7 }}>{v.name}</button>))}
          </div>
        </div>
      </div>
    </div>
  );
}
import { createStation } from '../station.ts'
import type { StationDefinition } from '../station.ts'
import { DATUM, JERSEY_LAT, JERSEY_LON, ST_HELIER_CONSTITUENTS } from './st-helier.data.ts'

export { DATUM, JERSEY_LAT, JERSEY_LON, ST_HELIER_CONSTITUENTS } from './st-helier.data.ts'

export const ST_HELIER: StationDefinition = {
  id: 'st-helier',
  name: 'St Helier, Jersey',
  latitude: JERSEY_LAT,
  longitude: JERSEY_LON,
  timeZone: 'Europe/Jersey',
  datum: DATUM,
  constituents: ST_HELIER_CONSTITUENTS
}

export const stHelier = createStation(ST_HELIER)

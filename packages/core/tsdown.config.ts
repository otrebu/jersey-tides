import { defineConfig } from 'tsdown'

export default defineConfig({
  entry: ['src/index.ts', 'src/stations/st-helier.ts'],
  format: 'esm',
  dts: true,
  clean: true,
  target: 'es2022',
  platform: 'neutral'
})

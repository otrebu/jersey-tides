import { build } from 'esbuild'
import { copyFileSync, existsSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = dirname(fileURLToPath(import.meta.url))

// Scriptable requires these exact three lines at the very top of the file.
const banner = [
  '// Variables used by Scriptable.',
  '// These must be at the very top of the file. Do not edit.',
  '// icon-color: deep-blue; icon-glyph: water;'
].join('\n')

await build({
  entryPoints: [join(root, 'src/widget.ts')],
  outfile: join(root, 'dist/Tides.js'),
  bundle: true,
  format: 'iife',
  target: 'es2020',
  minify: false,
  charset: 'utf8',
  banner: { js: banner },
  define: { BUILD_TIME: JSON.stringify(new Date().toISOString().slice(0, 16) + 'Z') },
  logLevel: 'info'
})

// Sync to the iCloud Scriptable folder when it exists (dev Mac); CI has none.
const icloud = join(homedir(), 'Library/Mobile Documents/iCloud~dk~simonbs~Scriptable/Documents')
if (existsSync(icloud)) {
  copyFileSync(join(root, 'dist/Tides.js'), join(icloud, 'Tides.js'))
  console.log('→ synced Tides.js to iCloud Scriptable')
} else {
  console.log('iCloud Scriptable folder not found — skipped device sync')
}

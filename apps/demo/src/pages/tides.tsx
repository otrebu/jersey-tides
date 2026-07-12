import { TideWidget } from '@u-b/tides-react'
import '@u-b/tides-react/styles.css'

export function TidesPage() {
  return (
    <div className="min-h-screen bg-[var(--bg)] p-4 text-[var(--text)]">
      <div className="mx-auto w-full max-w-[360px] md:max-w-[480px] lg:max-w-[540px]">
        <TideWidget />
      </div>
    </div>
  )
}

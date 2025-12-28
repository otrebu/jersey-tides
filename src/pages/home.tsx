import { Link } from '@tanstack/react-router'

export function HomePage() {
  return (
    <div className="min-h-screen bg-[var(--bg)] flex flex-col items-center justify-center p-4 text-[var(--text)]">
      <div className="text-center">
        <h1 className="text-4xl md:text-5xl font-black tracking-widest mb-2 border-b-[3px] border-[#111] pb-2">
          UB.JE
        </h1>
        <p className="text-sm md:text-base text-[var(--text-muted)] tracking-wider mb-8">
          Coming Soon
        </p>
        <Link
          to="/tides"
          className="inline-block text-sm tracking-wider border-2 border-[#111] px-4 py-2 hover:bg-[#111] hover:text-white transition-colors"
        >
          In the meantime, check out Jersey Tides &rarr;
        </Link>
      </div>
    </div>
  )
}

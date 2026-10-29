// Decorative page backdrop: obsidian base, soft nebula glows, a fading grid,
// faint film grain and a few slow embers. Pure CSS (no blur filters, no JS),
// so it costs next to nothing to paint. Render it inside an `isolate` container.

const GRAIN =
  "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='3' stitchTiles='stitch'/><feColorMatrix values='0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 1.4 -0.2'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>\")";

/** left %, start top %, size px, duration s, delay s, color */
const EMBERS: [number, number, number, number, number, string][] = [
  [8, 92, 2, 22, -3, "#c4b5fd"],
  [17, 70, 3, 28, -14, "#f6f4ff"],
  [29, 96, 2, 19, -8, "#67e8f9"],
  [41, 84, 2, 26, -20, "#c4b5fd"],
  [55, 100, 3, 24, -5, "#f6f4ff"],
  [63, 78, 2, 21, -16, "#a78bfa"],
  [74, 94, 2, 30, -11, "#67e8f9"],
  [83, 74, 3, 23, -2, "#c4b5fd"],
  [92, 98, 2, 27, -18, "#f6f4ff"],
  [47, 60, 2, 32, -25, "#f0abfc"],
];

const CSS = `
@keyframes nt-ember-rise {
  0%   { transform: translate3d(0, 0, 0) scale(1); opacity: 0; }
  12%  { opacity: .75; }
  55%  { transform: translate3d(14px, -34vh, 0) scale(.9); opacity: .55; }
  100% { transform: translate3d(-10px, -70vh, 0) scale(.5); opacity: 0; }
}
@keyframes nt-nebula-breathe {
  0%, 100% { opacity: .85; transform: scale(1); }
  50%      { opacity: 1;   transform: scale(1.04); }
}
.nt-ember { animation: nt-ember-rise var(--d) linear var(--delay) infinite; will-change: transform, opacity; }
.nt-nebula { animation: nt-nebula-breathe 14s ease-in-out infinite; transform-origin: 20% 0%; }
@media (prefers-reduced-motion: reduce) {
  .nt-ember { animation: none !important; opacity: .35; }
  .nt-nebula { animation: none !important; }
}
`;

export function Backdrop() {
  return (
    <div aria-hidden="true" className="pointer-events-none fixed inset-0 -z-10 overflow-hidden bg-obsidian-950">
      <style>{CSS}</style>

      {/* Nebula glows: violet top-left, faint pink right, cyan bottom-right. */}
      <div
        className="nt-nebula absolute inset-0"
        style={{
          backgroundImage: [
            "radial-gradient(60rem 42rem at 12% -8%, rgba(124,58,237,.30), transparent 62%)",
            "radial-gradient(34rem 26rem at 30% 8%, rgba(196,181,253,.10), transparent 70%)",
            "radial-gradient(36rem 30rem at 96% 38%, rgba(240,171,252,.07), transparent 70%)",
            "radial-gradient(52rem 38rem at 100% 108%, rgba(34,211,238,.14), transparent 64%)",
          ].join(","),
        }}
      />

      {/* Fine grid, fading out from the top. */}
      <div
        className="absolute inset-0"
        style={{
          backgroundImage:
            "linear-gradient(rgba(255,255,255,.035) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,.035) 1px, transparent 1px)",
          backgroundSize: "44px 44px",
          backgroundPosition: "-1px -1px",
          WebkitMaskImage: "radial-gradient(ellipse 90% 60% at 50% 0%, #000 20%, transparent 72%)",
          maskImage: "radial-gradient(ellipse 90% 60% at 50% 0%, #000 20%, transparent 72%)",
        }}
      />

      {/* Horizon line glow under the navbar. */}
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-spirit-violet/40 to-transparent" />

      {/* Embers. */}
      {EMBERS.map(([left, top, size, d, delay, color], i) => (
        <span
          key={i}
          className="nt-ember absolute rounded-full"
          style={
            {
              left: `${left}%`,
              top: `${top}%`,
              width: size,
              height: size,
              background: color,
              boxShadow: `0 0 ${size * 4}px ${size}px ${color}55`,
              "--d": `${d}s`,
              "--delay": `${delay}s`,
            } as React.CSSProperties
          }
        />
      ))}

      {/* Film grain. */}
      <div className="absolute inset-0 opacity-[0.045]" style={{ backgroundImage: GRAIN, backgroundSize: "160px 160px" }} />

      {/* Vignette keeps the edges deep. */}
      <div className="absolute inset-0" style={{ background: "radial-gradient(ellipse 120% 90% at 50% 40%, transparent 55%, rgba(2,2,6,.65) 100%)" }} />
    </div>
  );
}

export default Backdrop;

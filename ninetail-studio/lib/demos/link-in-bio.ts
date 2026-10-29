// Demo build for the "Creator Link-in-Bio Store" template: a mobile-first store
// for a fictional lo-fi producer, with a working cart drawer and newsletter form.
// The source is embedded verbatim with String.raw (it contains no backticks and
// no "${"), so `code` is exactly the file the studio shows and exports.

import type { DemoParts } from "./util";

const code = String.raw`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Noa Vance | Sample packs, presets and feedback sessions</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,700;12..96,800&family=DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,700&display=swap" rel="stylesheet">
  <script>
    tailwind.config = {
      theme: {
        extend: {
          colors: {
            night: { DEFAULT: "#0a0710", 900: "#110c19", 800: "#181122", 700: "#221830" },
            blush: { DEFAULT: "#f0abfc", soft: "#f5d0fe", deep: "#c026d3" }
          },
          fontFamily: {
            sans: ["DM Sans", "ui-sans-serif", "system-ui", "sans-serif"],
            display: ["Bricolage Grotesque", "DM Sans", "ui-sans-serif", "sans-serif"]
          }
        }
      }
    };
  </script>
  <style>
    html, body { background: #0a0710; overflow-x: clip; }
    .aura { background: radial-gradient(55% 40% at 50% 0%, rgba(240, 171, 252, 0.20), transparent 70%), radial-gradient(35% 30% at 0% 40%, rgba(192, 38, 211, 0.12), transparent 70%), radial-gradient(35% 30% at 100% 80%, rgba(129, 140, 248, 0.10), transparent 70%); }
    .ring-spin { background: conic-gradient(from 0deg, #f0abfc, #818cf8, #22d3ee, #f0abfc); animation: spin 8s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
    #cart-panel { visibility: hidden; transition: transform .3s ease-out, visibility 0s linear .3s; }
    #cart-panel[data-open="true"] { transform: translate(0, 0); visibility: visible; transition: transform .3s ease-out, visibility 0s; }
    #cart-overlay[data-open="true"] { opacity: 1; pointer-events: auto; }
    .bump { animation: bump .35s ease; }
    @keyframes bump { 40% { transform: scale(1.25); } }
    @media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation: none !important; transition: none !important; } }
  </style>
</head>
<body class="min-h-screen bg-night font-sans text-zinc-100 antialiased selection:bg-blush/30">
  <div class="pointer-events-none fixed inset-0 aura" aria-hidden="true"></div>

  <header class="sticky top-0 z-30 border-b border-white/5 bg-night/70 backdrop-blur-xl">
    <div class="mx-auto flex max-w-6xl items-center justify-between px-4 py-3 sm:px-6">
      <a href="#" class="rounded-md font-display text-lg font-extrabold tracking-tight focus:outline-none focus-visible:ring-2 focus-visible:ring-blush">noa<span class="text-blush">.</span>vance</a>
      <button id="cart-open" type="button" class="relative inline-flex h-11 items-center gap-2 rounded-full border border-white/10 bg-white/[0.05] pl-4 pr-3 text-sm font-semibold transition hover:bg-white/10 focus:outline-none focus-visible:ring-2 focus-visible:ring-blush" aria-label="Open cart, 0 items" aria-haspopup="dialog" aria-controls="cart-panel">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 7h12l-1 13H7L6 7Z"/><path d="M9 7a3 3 0 0 1 6 0"/></svg>
        Cart
        <span id="cart-count" class="grid h-6 min-w-6 place-items-center rounded-full bg-blush px-1.5 text-xs font-bold text-night">0</span>
      </button>
    </div>
  </header>

  <main class="relative mx-auto grid max-w-6xl gap-10 px-4 pb-16 pt-8 sm:px-6 lg:grid-cols-[380px_1fr] lg:gap-14 lg:pt-14">
    <!-- Profile column -->
    <aside class="lg:sticky lg:top-24 lg:self-start">
      <div class="flex flex-col items-center text-center lg:items-start lg:text-left">
        <div class="relative h-28 w-28">
          <div class="ring-spin absolute inset-0 rounded-full" aria-hidden="true"></div>
          <div class="absolute inset-[3px] grid place-items-center rounded-full bg-gradient-to-br from-[#3b1d4a] via-[#24163a] to-[#121a3a] font-display text-4xl font-extrabold tracking-tight text-blush-soft" role="img" aria-label="Noa Vance avatar">NV</div>
          <span class="absolute bottom-1.5 right-1.5 h-4 w-4 rounded-full border-[3px] border-night bg-emerald-400" title="Online"></span>
        </div>
        <h1 class="mt-5 font-display text-4xl font-extrabold tracking-[-0.03em]">Noa Vance</h1>
        <p class="mt-1 text-sm font-medium text-blush">@noavance &middot; lo-fi producer</p>
        <p class="mt-4 max-w-sm text-pretty text-[15px] leading-relaxed text-zinc-300">I make warm, dusty beats and the sounds behind them: drums from old tape decks, rain recorded on night buses, keys run through a broken chorus pedal.</p>

        <nav class="mt-6 flex gap-2.5" aria-label="Social links">
          <a href="#" aria-label="YouTube" class="grid h-11 w-11 place-items-center rounded-full border border-white/10 bg-white/[0.04] transition hover:-translate-y-0.5 hover:border-blush/40 hover:text-blush focus:outline-none focus-visible:ring-2 focus-visible:ring-blush"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><rect x="2.5" y="5.5" width="19" height="13" rx="4"/><path d="m10 9.5 5 2.5-5 2.5Z" fill="currentColor"/></svg></a>
          <a href="#" aria-label="Instagram" class="grid h-11 w-11 place-items-center rounded-full border border-white/10 bg-white/[0.04] transition hover:-translate-y-0.5 hover:border-blush/40 hover:text-blush focus:outline-none focus-visible:ring-2 focus-visible:ring-blush"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><rect x="3.5" y="3.5" width="17" height="17" rx="5"/><circle cx="12" cy="12" r="3.8"/><circle cx="17.2" cy="6.8" r="1" fill="currentColor"/></svg></a>
          <a href="#" aria-label="TikTok" class="grid h-11 w-11 place-items-center rounded-full border border-white/10 bg-white/[0.04] transition hover:-translate-y-0.5 hover:border-blush/40 hover:text-blush focus:outline-none focus-visible:ring-2 focus-visible:ring-blush"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M14 4v10.5a3.5 3.5 0 1 1-3.5-3.5"/><path d="M14 4c.5 2.6 2.2 4.2 5 4.5"/></svg></a>
          <a href="#" aria-label="Spotify" class="grid h-11 w-11 place-items-center rounded-full border border-white/10 bg-white/[0.04] transition hover:-translate-y-0.5 hover:border-blush/40 hover:text-blush focus:outline-none focus-visible:ring-2 focus-visible:ring-blush"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M7.5 9.5c3-1 6.5-.8 9.2.7M8.2 12.6c2.4-.7 5-.5 7.2.7M9 15.5c1.8-.5 3.6-.3 5.2.5"/></svg></a>
        </nav>
      </div>

      <ul class="mt-8 space-y-3">
        <li><a href="#" class="group flex min-h-[56px] items-center gap-3 rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-3 transition hover:border-blush/40 hover:bg-white/[0.07] focus:outline-none focus-visible:ring-2 focus-visible:ring-blush">
          <span class="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-rose-400/15 text-rose-300"><svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M8 5.5v13l10.5-6.5Z"/></svg></span>
          <span class="text-[15px] font-semibold">Watch: the rainy night bus beat</span>
          <svg class="ml-auto shrink-0 text-zinc-500 transition group-hover:translate-x-0.5 group-hover:text-blush" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M7 17 17 7M9 7h8v8"/></svg>
        </a></li>
        <li><a href="#" class="group flex min-h-[56px] items-center gap-3 rounded-2xl border border-blush/30 bg-blush/10 px-4 py-3 transition hover:bg-blush/15 focus:outline-none focus-visible:ring-2 focus-visible:ring-blush">
          <span class="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-blush/20 text-blush"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4v11m0 0 4-4m-4 4-4-4M5 19h14"/></svg></span>
          <span class="text-[15px] font-semibold">Free kit: 12 drum one-shots</span>
          <svg class="ml-auto shrink-0 text-blush transition group-hover:translate-x-0.5" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M7 17 17 7M9 7h8v8"/></svg>
        </a></li>
        <li><a href="#" class="group flex min-h-[56px] items-center gap-3 rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-3 transition hover:border-blush/40 hover:bg-white/[0.07] focus:outline-none focus-visible:ring-2 focus-visible:ring-blush">
          <span class="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-emerald-400/15 text-emerald-300"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M4 14v-2a8 8 0 0 1 16 0v2"/><rect x="3" y="14" width="4" height="6" rx="1.5"/><rect x="17" y="14" width="4" height="6" rx="1.5"/></svg></span>
          <span class="text-[15px] font-semibold">Listen to the <em>Night Bus</em> EP</span>
          <svg class="ml-auto shrink-0 text-zinc-500 transition group-hover:translate-x-0.5 group-hover:text-blush" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M7 17 17 7M9 7h8v8"/></svg>
        </a></li>
      </ul>
    </aside>

    <!-- Shop column -->
    <div>
      <section aria-labelledby="shop-title">
        <div class="flex flex-col items-start gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p class="text-xs font-bold uppercase tracking-[0.18em] text-blush">Shop</p>
            <h2 id="shop-title" class="mt-2 font-display text-3xl font-extrabold tracking-[-0.03em] sm:text-4xl">Sounds &amp; sessions</h2>
          </div>
          <p class="rounded-full border border-blush/30 bg-blush/10 px-3 py-1 text-xs font-bold text-blush-soft">Any 3, save 15%</p>
        </div>

        <div id="products" class="mt-6 grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-2">
          <article class="group flex flex-col overflow-hidden rounded-3xl border border-white/[0.08] bg-night-900/80 transition hover:-translate-y-1 hover:border-blush/30">
            <div class="relative aspect-square overflow-hidden" role="img" aria-label="Night Market Drum Kit cover art">
              <svg viewBox="0 0 100 100" class="h-full w-full transition duration-500 group-hover:scale-105" preserveAspectRatio="xMidYMid slice" aria-hidden="true"><defs><linearGradient id="a1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2a1145"/><stop offset="1" stop-color="#7a1d5c"/></linearGradient><linearGradient id="a2" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fde68a"/><stop offset="1" stop-color="#f472b6"/></linearGradient></defs><rect width="100" height="100" fill="url(#a1)"/><clipPath id="a3"><circle cx="50" cy="58" r="26"/></clipPath><circle cx="50" cy="58" r="26" fill="url(#a2)"/><g fill="#6a1a58" clip-path="url(#a3)"><rect x="20" y="62" width="60" height="2.5"/><rect x="20" y="68" width="60" height="3.5"/><rect x="20" y="75" width="60" height="4.5"/></g><rect y="80" width="100" height="20" fill="#1b0b2c"/><path d="M0 80h100" stroke="#f0abfc" stroke-width=".6" opacity=".7"/></svg>
              <span class="absolute left-3 top-3 rounded-full bg-night/70 px-2 py-0.5 text-[11px] font-bold backdrop-blur">New</span>
            </div>
            <div class="flex flex-1 flex-col p-3 sm:p-4">
              <h3 class="font-display text-[15px] font-bold leading-tight sm:text-lg">Night Market Drum Kit</h3>
              <p class="mt-1 text-[13px] leading-snug text-zinc-400">84 dusty drums, tape-saturated</p>
              <div class="mt-auto flex flex-wrap items-center justify-between gap-2 pt-3">
                <span class="font-display text-lg font-bold">$24</span>
                <button type="button" data-add="drums" class="h-11 min-w-[44px] flex-1 rounded-full bg-blush px-3 text-[13px] font-bold text-night transition hover:bg-blush-soft active:scale-95 focus:outline-none focus-visible:ring-2 focus-visible:ring-white sm:flex-none sm:px-4">Add to cart</button>
              </div>
            </div>
          </article>

          <article class="group flex flex-col overflow-hidden rounded-3xl border border-white/[0.08] bg-night-900/80 transition hover:-translate-y-1 hover:border-blush/30">
            <div class="relative aspect-square overflow-hidden" role="img" aria-label="Tape Hiss Vol. 2 cover art">
              <svg viewBox="0 0 100 100" class="h-full w-full transition duration-500 group-hover:scale-105" preserveAspectRatio="xMidYMid slice" aria-hidden="true"><defs><linearGradient id="b1" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#0f2a3d"/><stop offset="1" stop-color="#1e1b4b"/></linearGradient></defs><rect width="100" height="100" fill="url(#b1)"/><g transform="rotate(-8 50 50)"><rect x="16" y="30" width="68" height="42" rx="5" fill="#e0f2fe"/><rect x="22" y="36" width="56" height="16" rx="3" fill="#f0abfc"/><rect x="30" y="56" width="40" height="12" rx="6" fill="#0f172a"/><circle cx="38" cy="62" r="4" fill="#e0f2fe"/><circle cx="62" cy="62" r="4" fill="#e0f2fe"/><path d="M26 44h30" stroke="#0f172a" stroke-width="1.6" stroke-linecap="round"/></g></svg>
            </div>
            <div class="flex flex-1 flex-col p-3 sm:p-4">
              <h3 class="font-display text-[15px] font-bold leading-tight sm:text-lg">Tape Hiss Vol. 2</h3>
              <p class="mt-1 text-[13px] leading-snug text-zinc-400">120 textures from a 1987 cassette deck</p>
              <div class="mt-auto flex flex-wrap items-center justify-between gap-2 pt-3">
                <span class="font-display text-lg font-bold">$18</span>
                <button type="button" data-add="tape" class="h-11 min-w-[44px] flex-1 rounded-full bg-blush px-3 text-[13px] font-bold text-night transition hover:bg-blush-soft active:scale-95 focus:outline-none focus-visible:ring-2 focus-visible:ring-white sm:flex-none sm:px-4">Add to cart</button>
              </div>
            </div>
          </article>

          <article class="group flex flex-col overflow-hidden rounded-3xl border border-white/[0.08] bg-night-900/80 transition hover:-translate-y-1 hover:border-blush/30">
            <div class="relative aspect-square overflow-hidden" role="img" aria-label="Rainroom Keys cover art">
              <svg viewBox="0 0 100 100" class="h-full w-full transition duration-500 group-hover:scale-105" preserveAspectRatio="xMidYMid slice" aria-hidden="true"><defs><linearGradient id="c1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1e1b4b"/><stop offset="1" stop-color="#4c1d95"/></linearGradient></defs><rect width="100" height="100" fill="url(#c1)"/><g stroke="#a5b4fc" stroke-width="1" stroke-linecap="round" opacity=".55"><path d="M14 8l-6 16M34 4l-6 16M58 10l-6 16M82 6l-6 16M24 30l-6 16M48 26l-6 16M72 32l-6 16M94 28l-6 16"/></g><rect x="10" y="62" width="80" height="26" rx="3" fill="#f5f3ff"/><g fill="#1e1b4b"><rect x="19" y="62" width="5" height="15" rx="1"/><rect x="30" y="62" width="5" height="15" rx="1"/><rect x="47" y="62" width="5" height="15" rx="1"/><rect x="58" y="62" width="5" height="15" rx="1"/><rect x="69" y="62" width="5" height="15" rx="1"/></g><g stroke="#c7d2fe" stroke-width=".6"><path d="M21.5 77v11M32.5 77v11M44 62v26M49.5 77v11M60.5 77v11M71.5 77v11M80 62v26"/></g></svg>
              <span class="absolute left-3 top-3 rounded-full bg-night/70 px-2 py-0.5 text-[11px] font-bold backdrop-blur">Vital</span>
            </div>
            <div class="flex flex-1 flex-col p-3 sm:p-4">
              <h3 class="font-display text-[15px] font-bold leading-tight sm:text-lg">Rainroom Keys</h3>
              <p class="mt-1 text-[13px] leading-snug text-zinc-400">40 warm keys and pad presets</p>
              <div class="mt-auto flex flex-wrap items-center justify-between gap-2 pt-3">
                <span class="font-display text-lg font-bold">$29</span>
                <button type="button" data-add="keys" class="h-11 min-w-[44px] flex-1 rounded-full bg-blush px-3 text-[13px] font-bold text-night transition hover:bg-blush-soft active:scale-95 focus:outline-none focus-visible:ring-2 focus-visible:ring-white sm:flex-none sm:px-4">Add to cart</button>
              </div>
            </div>
          </article>

          <article class="group flex flex-col overflow-hidden rounded-3xl border border-white/[0.08] bg-night-900/80 transition hover:-translate-y-1 hover:border-blush/30">
            <div class="relative aspect-square overflow-hidden" role="img" aria-label="Beat Feedback Session cover art">
              <svg viewBox="0 0 100 100" class="h-full w-full transition duration-500 group-hover:scale-105" preserveAspectRatio="xMidYMid slice" aria-hidden="true"><defs><radialGradient id="d1" cx=".5" cy=".5" r=".7"><stop offset="0" stop-color="#3b0f3a"/><stop offset="1" stop-color="#120a1c"/></radialGradient></defs><rect width="100" height="100" fill="url(#d1)"/><circle cx="50" cy="50" r="34" fill="#0b0710"/><g fill="none" stroke="#f0abfc" stroke-opacity=".18"><circle cx="50" cy="50" r="30"/><circle cx="50" cy="50" r="26"/><circle cx="50" cy="50" r="22"/><circle cx="50" cy="50" r="18"/></g><circle cx="50" cy="50" r="11" fill="#f0abfc"/><circle cx="50" cy="50" r="2" fill="#0b0710"/><path d="M76 20 62 40" stroke="#e4e4e7" stroke-width="2.4" stroke-linecap="round"/><circle cx="77" cy="19" r="4" fill="#e4e4e7"/></svg>
              <span class="absolute left-3 top-3 rounded-full bg-night/70 px-2 py-0.5 text-[11px] font-bold backdrop-blur">Live</span>
            </div>
            <div class="flex flex-1 flex-col p-3 sm:p-4">
              <h3 class="font-display text-[15px] font-bold leading-tight sm:text-lg">1:1 Beat Feedback</h3>
              <p class="mt-1 text-[13px] leading-snug text-zinc-400">30-minute video call, notes after</p>
              <div class="mt-auto flex flex-wrap items-center justify-between gap-2 pt-3">
                <span class="font-display text-lg font-bold">$45</span>
                <button type="button" data-add="session" class="h-11 min-w-[44px] flex-1 rounded-full bg-blush px-3 text-[13px] font-bold text-night transition hover:bg-blush-soft active:scale-95 focus:outline-none focus-visible:ring-2 focus-visible:ring-white sm:flex-none sm:px-4">Add to cart</button>
              </div>
            </div>
          </article>
        </div>
      </section>

      <!-- Newsletter -->
      <section class="relative mt-10 overflow-hidden rounded-3xl border border-white/10 bg-gradient-to-br from-blush/[0.14] via-night-900 to-night-900 p-6 sm:p-8" aria-labelledby="nl-title">
        <div class="absolute -right-16 -top-16 h-48 w-48 rounded-full bg-blush/20 blur-3xl" aria-hidden="true"></div>
        <div class="relative">
          <h2 id="nl-title" class="font-display text-2xl font-extrabold tracking-[-0.02em] sm:text-3xl">Sunday Samples</h2>
          <p class="mt-2 max-w-md text-[15px] leading-relaxed text-zinc-300">One free sound in your inbox every Sunday, plus first dibs on new packs.</p>
          <form id="newsletter" class="mt-5 flex flex-col gap-3 sm:flex-row" novalidate>
            <label for="nl-email" class="sr-only">Email address</label>
            <input id="nl-email" type="email" autocomplete="email" required placeholder="you@example.com" class="h-12 w-full rounded-full border border-white/10 bg-night/60 px-5 text-[15px] placeholder:text-zinc-500 focus:border-blush/60 focus:outline-none focus:ring-2 focus:ring-blush/40">
            <button type="submit" class="h-12 shrink-0 rounded-full bg-white px-6 text-[15px] font-bold text-night transition hover:bg-blush-soft active:scale-[.98] focus:outline-none focus-visible:ring-2 focus-visible:ring-blush">Subscribe</button>
          </form>
          <p id="nl-error" class="mt-2 hidden pl-1 text-sm text-rose-300" role="alert">That email doesn't look right. Try again?</p>
          <p id="nl-success" class="mt-5 hidden items-center gap-3 rounded-2xl border border-blush/30 bg-blush/10 px-4 py-3 text-[15px] font-semibold text-blush-soft" role="status">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m5 12.5 4.5 4.5L19 7.5"/></svg>
            You're in. First sound lands this Sunday.
          </p>
        </div>
      </section>

      <footer class="mt-10 flex flex-wrap items-center justify-between gap-3 text-[13px] text-zinc-500">
        <p>&copy; <span id="year">2026</span> Noa Vance. Instant downloads, WAV 24-bit.</p>
        <a href="#" class="transition hover:text-zinc-300">Licensing &amp; refunds</a>
      </footer>
    </div>
  </main>

  <!-- Cart drawer -->
  <div id="cart-overlay" class="pointer-events-none fixed inset-0 z-40 bg-black/60 opacity-0 backdrop-blur-sm transition-opacity duration-300" aria-hidden="true"></div>
  <section id="cart-panel" role="dialog" aria-modal="true" aria-labelledby="cart-title" data-open="false" class="fixed inset-x-0 bottom-0 z-50 flex max-h-[85vh] translate-y-full flex-col rounded-t-[1.75rem] border border-white/10 bg-night-900 shadow-2xl md:inset-y-0 md:left-auto md:right-0 md:max-h-none md:w-[420px] md:translate-x-full md:translate-y-0 md:rounded-none md:rounded-l-[1.75rem]" inert>
    <div class="mx-auto mt-2.5 h-1 w-10 rounded-full bg-white/15 md:hidden" aria-hidden="true"></div>
    <div class="flex items-center justify-between px-5 pb-3 pt-3 md:pt-6">
      <h2 id="cart-title" class="font-display text-xl font-extrabold">Your cart <span id="cart-title-count" class="text-zinc-500">(0)</span></h2>
      <button id="cart-close" type="button" class="grid h-11 w-11 place-items-center rounded-full border border-white/10 text-zinc-300 transition hover:bg-white/10 focus:outline-none focus-visible:ring-2 focus-visible:ring-blush" aria-label="Close cart"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18"/></svg></button>
    </div>
    <ul id="cart-items" class="flex-1 space-y-2 overflow-y-auto px-5 pb-2"></ul>
    <p id="cart-empty" class="px-5 pb-6 pt-2 text-[15px] text-zinc-400">Your cart is empty. Add a pack to get started.</p>
    <div class="border-t border-white/10 px-5 pb-6 pt-4">
      <p id="bundle-hint" class="mb-3 rounded-xl bg-blush/10 px-3 py-2 text-[13px] font-semibold text-blush-soft">Add 3 items to unlock 15% off.</p>
      <dl id="cart-totals" class="space-y-1.5 text-[15px]">
        <div class="flex justify-between text-zinc-400"><dt>Subtotal</dt><dd id="t-sub" class="tabular-nums">$0.00</dd></div>
        <div id="t-disc-row" class="hidden justify-between text-blush"><dt>Bundle discount (15%)</dt><dd id="t-disc" class="tabular-nums">-$0.00</dd></div>
        <div class="flex justify-between pt-1 font-display text-lg font-extrabold"><dt>Total</dt><dd id="t-total" class="tabular-nums">$0.00</dd></div>
      </dl>
      <button id="checkout" type="button" class="mt-4 h-12 w-full rounded-full bg-blush text-[15px] font-bold text-night transition hover:bg-blush-soft disabled:cursor-not-allowed disabled:opacity-40 focus:outline-none focus-visible:ring-2 focus-visible:ring-white">Checkout</button>
      <p id="checkout-note" class="mt-3 hidden text-center text-[13px] text-zinc-400" role="status">Checkout isn't connected in this preview. Your cart is saved on this page.</p>
    </div>
  </section>

  <script>
    (function () {
      var PRODUCTS = {
        drums: { name: "Night Market Drum Kit", price: 24, swatch: "linear-gradient(135deg,#f472b6,#7a1d5c)" },
        tape: { name: "Tape Hiss Vol. 2", price: 18, swatch: "linear-gradient(135deg,#e0f2fe,#1e1b4b)" },
        keys: { name: "Rainroom Keys", price: 29, swatch: "linear-gradient(135deg,#a5b4fc,#4c1d95)" },
        session: { name: "1:1 Beat Feedback", price: 45, swatch: "radial-gradient(circle,#f0abfc 30%,#120a1c 32%)" }
      };
      var cart = {}; // id -> quantity
      var lastFocus = null;

      var panel = document.getElementById("cart-panel");
      var overlay = document.getElementById("cart-overlay");
      var list = document.getElementById("cart-items");
      var openBtn = document.getElementById("cart-open");
      var countEl = document.getElementById("cart-count");
      var note = document.getElementById("checkout-note");
      var checkout = document.getElementById("checkout");

      function money(n) { return "$" + n.toFixed(2); }
      function qty() { var n = 0; for (var k in cart) n += cart[k]; return n; }

      function render() {
        var items = Object.keys(cart);
        var count = qty();
        var sub = 0;
        list.innerHTML = items.map(function (id) {
          var p = PRODUCTS[id];
          var q = cart[id];
          sub += p.price * q;
          return '<li class="flex gap-3 rounded-2xl border border-white/[0.07] bg-white/[0.03] p-3">' +
            '<span class="h-14 w-14 shrink-0 rounded-xl" style="background:' + p.swatch + '"></span>' +
            '<div class="min-w-0 flex-1">' +
            '<div class="flex items-start justify-between gap-2"><p class="text-[15px] font-semibold leading-snug">' + p.name + '</p>' +
            '<button type="button" data-remove="' + id + '" class="-mr-1.5 -mt-1.5 grid h-9 w-9 shrink-0 place-items-center rounded-full text-zinc-500 hover:bg-white/5 hover:text-rose-300" aria-label="Remove ' + p.name + ' from cart">' +
            '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 7h14M10 7V5h4v2M7 7l1 12h8l1-12"/></svg></button></div>' +
            '<div class="mt-1.5 flex items-center justify-between gap-2">' +
            '<div class="flex items-center rounded-full border border-white/10">' +
            '<button type="button" data-dec="' + id + '" class="grid h-9 w-9 place-items-center rounded-full text-lg text-zinc-300 hover:text-white" aria-label="Remove one ' + p.name + '">&minus;</button>' +
            '<span class="w-5 text-center text-sm font-bold tabular-nums" aria-label="Quantity">' + q + '</span>' +
            '<button type="button" data-inc="' + id + '" class="grid h-9 w-9 place-items-center rounded-full text-lg text-zinc-300 hover:text-white" aria-label="Add one ' + p.name + '">+</button></div>' +
            '<p class="text-[15px] font-bold tabular-nums">' + money(p.price * q) + '</p></div></div></li>';
        }).join("");

        var discount = count >= 3 ? Math.round(sub * 0.15 * 100) / 100 : 0;
        document.getElementById("t-sub").textContent = money(sub);
        document.getElementById("t-disc").textContent = "-" + money(discount);
        document.getElementById("t-total").textContent = money(sub - discount);
        var discRow = document.getElementById("t-disc-row");
        discRow.classList.toggle("hidden", discount === 0);
        discRow.classList.toggle("flex", discount > 0);

        var hint = document.getElementById("bundle-hint");
        hint.textContent = count >= 3 ? "Bundle unlocked: 15% off your order." : "Add " + (3 - count) + " more " + (3 - count === 1 ? "item" : "items") + " to unlock 15% off.";

        countEl.textContent = String(count);
        openBtn.setAttribute("aria-label", "Open cart, " + count + (count === 1 ? " item" : " items"));
        document.getElementById("cart-title-count").textContent = "(" + count + ")";
        document.getElementById("cart-empty").classList.toggle("hidden", count > 0);
        checkout.disabled = count === 0;
        if (count === 0) note.classList.add("hidden");
      }

      function setOpen(open) {
        panel.setAttribute("data-open", String(open));
        overlay.setAttribute("data-open", String(open));
        if (open) {
          panel.removeAttribute("inert");
          lastFocus = document.activeElement;
          document.getElementById("cart-close").focus();
        } else {
          panel.setAttribute("inert", "");
          note.classList.add("hidden");
          if (lastFocus && lastFocus.focus) lastFocus.focus();
        }
      }

      document.querySelectorAll("[data-add]").forEach(function (btn) {
        btn.addEventListener("click", function () {
          var id = btn.getAttribute("data-add");
          cart[id] = (cart[id] || 0) + 1;
          render();
          countEl.classList.remove("bump");
          void countEl.offsetWidth;
          countEl.classList.add("bump");
          var label = btn.textContent;
          btn.textContent = "Added";
          setTimeout(function () { btn.textContent = label; }, 1200);
          lastFocus = btn;
          setOpen(true);
        });
      });

      list.addEventListener("click", function (event) {
        var target = event.target.closest("button");
        if (!target) return;
        var id;
        if ((id = target.getAttribute("data-inc"))) cart[id]++;
        else if ((id = target.getAttribute("data-dec"))) { cart[id]--; if (cart[id] <= 0) delete cart[id]; }
        else if ((id = target.getAttribute("data-remove"))) delete cart[id];
        render();
        if (qty() === 0) document.getElementById("cart-close").focus();
      });

      openBtn.addEventListener("click", function () { setOpen(true); });
      document.getElementById("cart-close").addEventListener("click", function () { setOpen(false); });
      overlay.addEventListener("click", function () { setOpen(false); });
      document.addEventListener("keydown", function (event) {
        if (event.key === "Escape" && panel.getAttribute("data-open") === "true") setOpen(false);
      });
      checkout.addEventListener("click", function () { note.classList.remove("hidden"); });

      var form = document.getElementById("newsletter");
      form.addEventListener("submit", function (event) {
        event.preventDefault();
        var email = document.getElementById("nl-email");
        var ok = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email.value.trim());
        document.getElementById("nl-error").classList.toggle("hidden", ok);
        if (!ok) { email.setAttribute("aria-invalid", "true"); email.focus(); return; }
        form.classList.add("hidden");
        var done = document.getElementById("nl-success");
        done.classList.remove("hidden");
        done.classList.add("flex");
      });

      document.getElementById("year").textContent = String(new Date().getFullYear());
      render();
    })();
  </script>
</body>
</html>`;

export const linkInBioDemo: DemoParts = {
  title: "Noa Vance Link-in-Bio Store",
  language: "html",
  code,
  gui: null,
};

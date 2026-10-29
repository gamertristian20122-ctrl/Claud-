// Demo build for the "SaaS Waitlist Page" template: a complete Tailwind page for
// Lumen, a fictional AI note-taking app (email capture, countdown, FAQ).
// The source is embedded verbatim with String.raw (it contains no backticks and
// no "${"), so `code` is exactly the file the studio shows and exports.

import type { DemoParts } from "./util";

const code = String.raw`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Lumen | Your notes, already written</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <script>
    tailwind.config = {
      theme: {
        extend: {
          colors: {
            ink: { DEFAULT: "#07070c", 900: "#0c0c14", 800: "#12121c", 700: "#1a1a28" },
            lumen: { DEFAULT: "#a78bfa", soft: "#c4b5fd", deep: "#7c3aed" }
          },
          fontFamily: {
            sans: ["Manrope", "ui-sans-serif", "system-ui", "sans-serif"],
            serif: ["Instrument Serif", "ui-serif", "Georgia", "serif"]
          }
        }
      }
    };
  </script>
  <style>
    html, body { background: #07070c; overflow-x: clip; }
    .glow { background: radial-gradient(60% 50% at 50% 0%, rgba(167, 139, 250, 0.22), transparent 70%), radial-gradient(40% 40% at 90% 20%, rgba(124, 58, 237, 0.14), transparent 70%); }
    .grid-fade { background-image: linear-gradient(rgba(255,255,255,0.035) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.035) 1px, transparent 1px); background-size: 48px 48px; -webkit-mask-image: radial-gradient(70% 60% at 50% 20%, #000 30%, transparent 75%); mask-image: radial-gradient(70% 60% at 50% 20%, #000 30%, transparent 75%); }
    .wave span { display: inline-block; width: 3px; border-radius: 9999px; background: #c4b5fd; animation: wave 1.1s ease-in-out infinite; }
    .wave span:nth-child(2) { animation-delay: .15s } .wave span:nth-child(3) { animation-delay: .3s } .wave span:nth-child(4) { animation-delay: .45s } .wave span:nth-child(5) { animation-delay: .6s }
    @keyframes wave { 0%, 100% { height: 4px } 50% { height: 14px } }
    .caret::after { content: ""; display: inline-block; width: 2px; height: 1em; margin-left: 2px; vertical-align: -2px; background: #c4b5fd; animation: blink 1s steps(1) infinite; }
    @keyframes blink { 50% { opacity: 0 } }
    details summary::-webkit-details-marker { display: none; }
    details[open] .chev { transform: rotate(45deg); }
    @media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation: none !important; transition: none !important; scroll-behavior: auto !important; } }
  </style>
</head>
<body class="min-h-screen overflow-x-hidden bg-ink font-sans text-zinc-100 antialiased selection:bg-lumen/30">
  <div class="pointer-events-none fixed inset-0 glow" aria-hidden="true"></div>
  <div class="pointer-events-none absolute inset-x-0 top-0 h-[720px] grid-fade" aria-hidden="true"></div>

  <header class="sticky top-0 z-40 border-b border-white/5 bg-ink/70 backdrop-blur-xl">
    <div class="mx-auto flex max-w-6xl items-center justify-between px-5 py-3.5">
      <a href="#" class="flex items-center gap-2.5 rounded-lg font-bold tracking-tight focus:outline-none focus-visible:ring-2 focus-visible:ring-lumen">
        <svg width="28" height="28" viewBox="0 0 32 32" aria-hidden="true"><defs><linearGradient id="lg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ede9fe"/><stop offset="1" stop-color="#8b5cf6"/></linearGradient></defs><circle cx="16" cy="16" r="15" fill="url(#lg)" opacity=".16"/><path d="M16 6.5c1.2 5.2 4.3 8.3 9.5 9.5-5.2 1.2-8.3 4.3-9.5 9.5-1.2-5.2-4.3-8.3-9.5-9.5 5.2-1.2 8.3-4.3 9.5-9.5Z" fill="url(#lg)"/></svg>
        <span class="text-lg">Lumen</span>
      </a>
      <nav class="hidden items-center gap-8 text-sm text-zinc-400 md:flex" aria-label="Main">
        <a href="#features" class="transition hover:text-white">Features</a>
        <a href="#how" class="transition hover:text-white">How it works</a>
        <a href="#faq" class="transition hover:text-white">FAQ</a>
      </nav>
      <a href="#join" class="rounded-full bg-white px-4 py-2 text-sm font-semibold text-ink transition hover:bg-violet-100 focus:outline-none focus-visible:ring-2 focus-visible:ring-lumen focus-visible:ring-offset-2 focus-visible:ring-offset-ink">Join waitlist</a>
    </div>
  </header>

  <main class="relative">
    <!-- Hero -->
    <section class="mx-auto grid max-w-6xl items-center gap-12 px-5 pb-20 pt-14 sm:pt-20 lg:grid-cols-[1.05fr_1fr] lg:gap-14 lg:pt-24">
      <div>
        <p class="inline-flex items-center gap-2 rounded-full border border-lumen/25 bg-lumen/10 px-3 py-1 text-xs font-semibold text-violet-200">
          <span class="h-1.5 w-1.5 animate-pulse rounded-full bg-lumen-soft"></span>
          <span>Early access opens <span data-launch-label>soon</span></span>
        </p>
        <h1 class="mt-6 text-[2.75rem] font-extrabold leading-[1.02] tracking-[-0.035em] sm:text-6xl lg:text-7xl">
          Your notes,<br><span class="font-serif text-[1.12em] font-normal italic tracking-normal text-violet-200">already</span> written.
        </h1>
        <p class="mt-6 max-w-xl text-base leading-relaxed text-zinc-400 sm:text-lg">
          Lumen listens to your calls and voice memos, writes clean notes with decisions and action items, and lets you ask your whole archive anything.
        </p>

        <div id="join" class="mt-8 max-w-lg scroll-mt-24">
          <form id="waitlist" class="flex flex-col gap-3 sm:flex-row sm:rounded-full sm:border sm:border-white/10 sm:bg-white/[0.04] sm:p-1.5 sm:backdrop-blur" novalidate>
            <label for="email" class="sr-only">Work email</label>
            <input id="email" name="email" type="email" autocomplete="email" required placeholder="you@company.com"
              class="h-12 w-full rounded-full border border-white/10 bg-white/[0.04] px-5 text-[15px] text-white placeholder:text-zinc-500 focus:border-lumen/60 focus:outline-none focus:ring-2 focus:ring-lumen/40 sm:border-0 sm:bg-transparent sm:focus:ring-0">
            <button type="submit" class="h-12 shrink-0 rounded-full bg-gradient-to-b from-violet-300 to-lumen px-6 text-[15px] font-bold text-ink shadow-[0_8px_30px_-6px_rgba(167,139,250,.7)] transition hover:brightness-110 active:scale-[.98] focus:outline-none focus-visible:ring-2 focus-visible:ring-white">
              Get early access
            </button>
          </form>
          <p id="email-error" class="mt-2 hidden pl-1 text-sm text-rose-300" role="alert">Enter a valid email address, like you@company.com.</p>
          <div id="success" class="hidden rounded-3xl border border-lumen/30 bg-lumen/10 p-5" tabindex="-1">
            <div class="flex items-start gap-4">
              <span class="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-lumen text-ink">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m5 12.5 4.5 4.5L19 7.5"/></svg>
              </span>
              <div>
                <h2 class="text-lg font-bold">You're on the list.</h2>
                <p class="mt-1 text-sm leading-relaxed text-zinc-300">We'll send your invite to <strong id="success-email" class="font-semibold text-white"></strong> before doors open.</p>
                <button id="reset" type="button" class="mt-3 text-sm font-semibold text-violet-200 underline decoration-violet-300/40 underline-offset-4 hover:decoration-violet-200">Use a different email</button>
              </div>
            </div>
          </div>
          <p id="fineprint" class="mt-3 flex items-center gap-2 pl-1 text-[13px] text-zinc-500">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></svg>
            No spam. One email when your invite is ready.
          </p>
        </div>
      </div>

      <!-- Mock app window -->
      <div class="relative" aria-label="Preview of a Lumen meeting note" role="img">
        <div class="absolute -inset-3 rounded-[2.5rem] bg-lumen/20 blur-3xl sm:-inset-6" aria-hidden="true"></div>
        <div class="relative overflow-hidden rounded-3xl border border-white/10 bg-ink-900/90 shadow-2xl backdrop-blur-xl">
          <div class="flex items-center gap-3 border-b border-white/5 px-4 py-3">
            <div class="flex gap-1.5"><span class="h-2.5 w-2.5 rounded-full bg-white/15"></span><span class="h-2.5 w-2.5 rounded-full bg-white/15"></span><span class="h-2.5 w-2.5 rounded-full bg-white/15"></span></div>
            <p class="truncate text-[13px] font-semibold text-zinc-300">Weekly product sync</p>
            <span class="ml-auto inline-flex items-center gap-1.5 rounded-full bg-rose-500/15 px-2 py-0.5 text-[11px] font-bold tracking-wide text-rose-300"><span class="h-1.5 w-1.5 animate-pulse rounded-full bg-rose-400"></span>LIVE <span id="live-clock" class="tabular-nums">24:16</span></span>
          </div>
          <div class="space-y-3 p-4 sm:p-5">
            <div class="flex gap-3">
              <span class="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-sky-400/20 text-xs font-bold text-sky-200">AK</span>
              <p class="text-sm leading-relaxed text-zinc-300"><span class="font-semibold text-white">Ava</span> Let's lock the onboarding checklist this week so beta users see it first.</p>
            </div>
            <div class="flex gap-3">
              <span class="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-amber-400/20 text-xs font-bold text-amber-200">JM</span>
              <p class="text-sm leading-relaxed text-zinc-300"><span class="font-semibold text-white">Jordan</span> <span id="typing" class="caret">Agreed. Pricing can wait for the March release.</span></p>
            </div>
            <div class="flex items-center gap-2 pl-11 text-xs text-zinc-500"><span class="wave flex h-4 items-center gap-[3px]" aria-hidden="true"><span></span><span></span><span></span><span></span><span></span></span>Transcribing</div>

            <div class="rounded-2xl border border-lumen/20 bg-gradient-to-b from-lumen/[0.12] to-transparent p-4">
              <p class="flex items-center gap-2 text-xs font-bold uppercase tracking-[0.14em] text-violet-200">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 2.5c.9 4.4 3.6 7.1 8 8-4.4.9-7.1 3.6-8 8-.9-4.4-3.6-7.1-8-8 4.4-.9 7.1-3.6 8-8Z"/></svg>Summary so far
              </p>
              <ul class="mt-3 space-y-2 text-sm text-zinc-200">
                <li class="flex gap-2.5"><span class="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-lumen"></span>Onboarding checklist ships before Friday.</li>
                <li class="flex gap-2.5"><span class="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-lumen"></span>Pricing page moves to the March release.</li>
                <li class="flex gap-2.5"><span class="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-lumen"></span><span><span class="rounded bg-white/10 px-1.5 py-0.5 text-xs font-semibold">Jordan</span> owns the beta invite email.</span></li>
              </ul>
            </div>

            <div class="flex items-center gap-3 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#c4b5fd" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>
              <p class="truncate text-sm text-zinc-400">What did we decide about pricing?</p>
              <kbd class="ml-auto hidden rounded-md border border-white/10 px-1.5 py-0.5 font-sans text-[11px] text-zinc-400 sm:inline">Ctrl K</kbd>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Features -->
    <section id="features" class="mx-auto max-w-6xl scroll-mt-20 px-5 py-14 sm:py-16">
      <p class="text-xs font-bold uppercase tracking-[0.18em] text-lumen">What it does</p>
      <h2 class="mt-3 max-w-2xl text-3xl font-extrabold tracking-[-0.03em] sm:text-5xl">Built for people who&rsquo;d rather <span class="font-serif font-normal italic text-violet-200">listen.</span></h2>
      <div class="mt-10 grid gap-4 md:grid-cols-3">
        <article class="group rounded-3xl border border-white/[0.07] bg-white/[0.025] p-6 transition duration-300 hover:-translate-y-1 hover:border-lumen/30 hover:bg-white/[0.04]">
          <span class="grid h-11 w-11 place-items-center rounded-2xl bg-lumen/15 text-violet-200">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21"/></svg>
          </span>
          <h3 class="mt-5 text-lg font-bold">Live transcription</h3>
          <p class="mt-2 text-[15px] leading-relaxed text-zinc-400">Speaker-labelled transcripts as you talk, for video calls, in-person meetings and quick voice memos.</p>
        </article>
        <article class="group rounded-3xl border border-white/[0.07] bg-white/[0.025] p-6 transition duration-300 hover:-translate-y-1 hover:border-lumen/30 hover:bg-white/[0.04]">
          <span class="grid h-11 w-11 place-items-center rounded-2xl bg-lumen/15 text-violet-200">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 4h14v16l-3.5-2-3.5 2-3.5-2L5 20Z"/><path d="M9 9h6M9 13h4"/></svg>
          </span>
          <h3 class="mt-5 text-lg font-bold">Auto-summaries</h3>
          <p class="mt-2 text-[15px] leading-relaxed text-zinc-400">Decisions, action items and owners, pulled out the moment the call ends and ready to share.</p>
        </article>
        <article class="group rounded-3xl border border-white/[0.07] bg-white/[0.025] p-6 transition duration-300 hover:-translate-y-1 hover:border-lumen/30 hover:bg-white/[0.04]">
          <span class="grid h-11 w-11 place-items-center rounded-2xl bg-lumen/15 text-violet-200">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12a8.5 8.5 0 0 1-12.4 7.6L3 21l1.4-5.6A8.5 8.5 0 1 1 21 12Z"/><path d="M9.5 10a2.5 2.5 0 1 1 3.4 2.3c-.6.3-.9.8-.9 1.4M12 16.5h.01"/></svg>
          </span>
          <h3 class="mt-5 text-lg font-bold">Ask your notes</h3>
          <p class="mt-2 text-[15px] leading-relaxed text-zinc-400">Ask a question in plain words and get the answer, with a link to the exact moment it was said.</p>
        </article>
      </div>
    </section>

    <!-- How it works -->
    <section id="how" class="mx-auto max-w-6xl scroll-mt-20 px-5 py-14 sm:py-16">
      <p class="text-xs font-bold uppercase tracking-[0.18em] text-lumen">How it works</p>
      <h2 class="mt-3 text-3xl font-extrabold tracking-[-0.03em] sm:text-5xl">Three steps. Zero typing.</h2>
      <ol class="relative mt-10 grid gap-8 md:grid-cols-3 md:gap-6">
        <li class="relative border-l border-white/10 pl-6 md:border-l-0 md:border-t md:pl-0 md:pt-6">
          <span class="absolute -left-[5px] top-1 h-2.5 w-2.5 rounded-full bg-lumen shadow-[0_0_14px_#a78bfa] md:-top-[5px] md:left-0"></span>
          <p class="font-serif text-4xl italic text-violet-200">01</p>
          <h3 class="mt-2 text-lg font-bold">Connect your calendar</h3>
          <p class="mt-1.5 text-[15px] leading-relaxed text-zinc-400">Pick the calls Lumen should join. Nothing records without your say.</p>
        </li>
        <li class="relative border-l border-white/10 pl-6 md:border-l-0 md:border-t md:pl-0 md:pt-6">
          <span class="absolute -left-[5px] top-1 h-2.5 w-2.5 rounded-full bg-lumen shadow-[0_0_14px_#a78bfa] md:-top-[5px] md:left-0"></span>
          <p class="font-serif text-4xl italic text-violet-200">02</p>
          <h3 class="mt-2 text-lg font-bold">Talk like normal</h3>
          <p class="mt-1.5 text-[15px] leading-relaxed text-zinc-400">Stay in the conversation. Lumen keeps the notes and tags who said what.</p>
        </li>
        <li class="relative border-l border-white/10 pl-6 md:border-l-0 md:border-t md:pl-0 md:pt-6">
          <span class="absolute -left-[5px] top-1 h-2.5 w-2.5 rounded-full bg-lumen shadow-[0_0_14px_#a78bfa] md:-top-[5px] md:left-0"></span>
          <p class="font-serif text-4xl italic text-violet-200">03</p>
          <h3 class="mt-2 text-lg font-bold">Find anything later</h3>
          <p class="mt-1.5 text-[15px] leading-relaxed text-zinc-400">Ask a question and jump straight to the moment that answers it.</p>
        </li>
      </ol>
    </section>

    <!-- Countdown -->
    <section class="mx-auto max-w-6xl px-5 py-14 sm:py-16" aria-labelledby="countdown-title">
      <div class="relative overflow-hidden rounded-[2rem] border border-lumen/20 bg-gradient-to-br from-lumen/[0.14] via-ink-900 to-ink-900 p-6 sm:p-12">
        <div class="absolute -right-24 -top-24 h-72 w-72 rounded-full bg-lumen/25 blur-3xl" aria-hidden="true"></div>
        <div class="relative flex flex-col gap-8 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p class="text-xs font-bold uppercase tracking-[0.18em] text-violet-200">Launch day</p>
            <h2 id="countdown-title" class="mt-3 text-3xl font-extrabold tracking-[-0.03em] sm:text-5xl">Doors open <span data-launch-label class="font-serif font-normal italic text-violet-200">soon</span></h2>
            <p class="mt-3 max-w-md text-[15px] text-zinc-400">Invites go out in waitlist order. Join now to be in the first wave.</p>
          </div>
          <div class="grid grid-cols-4 gap-2 sm:gap-3" role="timer" aria-live="off" aria-label="Time until launch">
            <div class="rounded-2xl border border-white/10 bg-ink/60 px-2 py-3 text-center sm:min-w-[96px] sm:px-4 sm:py-4"><p data-unit="d" class="text-3xl font-extrabold tabular-nums tracking-tight sm:text-5xl">00</p><p class="mt-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-zinc-400">Days</p></div>
            <div class="rounded-2xl border border-white/10 bg-ink/60 px-2 py-3 text-center sm:min-w-[96px] sm:px-4 sm:py-4"><p data-unit="h" class="text-3xl font-extrabold tabular-nums tracking-tight sm:text-5xl">00</p><p class="mt-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-zinc-400">Hours</p></div>
            <div class="rounded-2xl border border-white/10 bg-ink/60 px-2 py-3 text-center sm:min-w-[96px] sm:px-4 sm:py-4"><p data-unit="m" class="text-3xl font-extrabold tabular-nums tracking-tight sm:text-5xl">00</p><p class="mt-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-zinc-400">Min</p></div>
            <div class="rounded-2xl border border-white/10 bg-ink/60 px-2 py-3 text-center sm:min-w-[96px] sm:px-4 sm:py-4"><p data-unit="s" class="text-3xl font-extrabold tabular-nums tracking-tight text-violet-200 sm:text-5xl">00</p><p class="mt-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-zinc-400">Sec</p></div>
          </div>
        </div>
      </div>
    </section>

    <!-- FAQ -->
    <section id="faq" class="mx-auto max-w-3xl scroll-mt-20 px-5 py-14 sm:py-16">
      <h2 class="text-3xl font-extrabold tracking-[-0.03em] sm:text-5xl">Questions, answered.</h2>
      <div class="mt-8 divide-y divide-white/[0.07] border-y border-white/[0.07]">
        <details class="group py-1" open>
          <summary class="flex cursor-pointer list-none items-center justify-between gap-4 rounded-lg py-4 text-left text-base font-semibold focus:outline-none focus-visible:ring-2 focus-visible:ring-lumen">When can I start using Lumen?<span class="chev grid h-8 w-8 shrink-0 place-items-center rounded-full border border-white/10 text-lg text-violet-200 transition">+</span></summary>
          <p class="pb-5 pr-10 text-[15px] leading-relaxed text-zinc-400">Invites go out in waves from launch day, in the order people joined the waitlist. You'll get one email with your invite link.</p>
        </details>
        <details class="group py-1">
          <summary class="flex cursor-pointer list-none items-center justify-between gap-4 rounded-lg py-4 text-left text-base font-semibold focus:outline-none focus-visible:ring-2 focus-visible:ring-lumen">Which meeting apps does it work with?<span class="chev grid h-8 w-8 shrink-0 place-items-center rounded-full border border-white/10 text-lg text-violet-200 transition">+</span></summary>
          <p class="pb-5 pr-10 text-[15px] leading-relaxed text-zinc-400">Zoom, Google Meet and Microsoft Teams at launch, plus any audio file or voice memo you upload.</p>
        </details>
        <details class="group py-1">
          <summary class="flex cursor-pointer list-none items-center justify-between gap-4 rounded-lg py-4 text-left text-base font-semibold focus:outline-none focus-visible:ring-2 focus-visible:ring-lumen">Who can see my notes?<span class="chev grid h-8 w-8 shrink-0 place-items-center rounded-full border border-white/10 text-lg text-violet-200 transition">+</span></summary>
          <p class="pb-5 pr-10 text-[15px] leading-relaxed text-zinc-400">Only you and the people you share them with. Recordings are encrypted at rest, and you can delete any of them at any time.</p>
        </details>
        <details class="group py-1">
          <summary class="flex cursor-pointer list-none items-center justify-between gap-4 rounded-lg py-4 text-left text-base font-semibold focus:outline-none focus-visible:ring-2 focus-visible:ring-lumen">What will it cost?<span class="chev grid h-8 w-8 shrink-0 place-items-center rounded-full border border-white/10 text-lg text-violet-200 transition">+</span></summary>
          <p class="pb-5 pr-10 text-[15px] leading-relaxed text-zinc-400">There will be a free plan for personal use. Everyone on the waitlist gets their first three months of Pro included.</p>
        </details>
        <details class="group py-1">
          <summary class="flex cursor-pointer list-none items-center justify-between gap-4 rounded-lg py-4 text-left text-base font-semibold focus:outline-none focus-visible:ring-2 focus-visible:ring-lumen">Can I bring my team?<span class="chev grid h-8 w-8 shrink-0 place-items-center rounded-full border border-white/10 text-lg text-violet-200 transition">+</span></summary>
          <p class="pb-5 pr-10 text-[15px] leading-relaxed text-zinc-400">Yes. Add your teammates after you join and you'll all be invited in the same wave.</p>
        </details>
      </div>
    </section>
  </main>

  <footer class="border-t border-white/5">
    <div class="mx-auto flex max-w-6xl flex-col gap-6 px-5 py-10 text-sm text-zinc-500 sm:flex-row sm:items-center sm:justify-between">
      <div class="flex items-center gap-2.5 font-bold text-zinc-200">
        <svg width="22" height="22" viewBox="0 0 32 32" aria-hidden="true"><path d="M16 6.5c1.2 5.2 4.3 8.3 9.5 9.5-5.2 1.2-8.3 4.3-9.5 9.5-1.2-5.2-4.3-8.3-9.5-9.5 5.2-1.2 8.3-4.3 9.5-9.5Z" fill="#a78bfa"/></svg>
        Lumen
        <span class="font-normal text-zinc-500">&copy; <span id="year">2026</span> Lumen Labs</span>
      </div>
      <nav class="flex gap-6" aria-label="Footer">
        <a href="#" class="transition hover:text-zinc-200">Privacy</a>
        <a href="#" class="transition hover:text-zinc-200">Terms</a>
        <a href="#" class="transition hover:text-zinc-200">Contact</a>
      </nav>
    </div>
  </footer>

  <script>
    (function () {
      var now = new Date();
      // Launch: the 1st of the month after next, 17:00 UTC. Always in the future.
      var launch = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 2, 1, 17, 0, 0));
      var label = launch.toLocaleDateString("en-US", { month: "long", day: "numeric" });
      document.querySelectorAll("[data-launch-label]").forEach(function (el) { el.textContent = label; });
      document.getElementById("year").textContent = String(now.getFullYear());

      var units = { d: 86400000, h: 3600000, m: 60000, s: 1000 };
      var cells = {};
      document.querySelectorAll("[data-unit]").forEach(function (el) { cells[el.getAttribute("data-unit")] = el; });
      function pad(n) { return n < 10 ? "0" + n : String(n); }
      function tick() {
        var left = Math.max(0, launch.getTime() - Date.now());
        ["d", "h", "m", "s"].forEach(function (u) {
          var v = Math.floor(left / units[u]);
          left -= v * units[u];
          cells[u].textContent = pad(v);
        });
      }
      tick();
      setInterval(tick, 1000);

      // The mock call's live timer.
      var clock = document.getElementById("live-clock");
      var elapsed = 24 * 60 + 16;
      setInterval(function () {
        elapsed++;
        clock.textContent = Math.floor(elapsed / 60) + ":" + pad(elapsed % 60);
      }, 1000);

      var form = document.getElementById("waitlist");
      var input = document.getElementById("email");
      var error = document.getElementById("email-error");
      var success = document.getElementById("success");
      var fineprint = document.getElementById("fineprint");
      form.addEventListener("submit", function (event) {
        event.preventDefault();
        var value = input.value.trim();
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value)) {
          error.classList.remove("hidden");
          input.setAttribute("aria-invalid", "true");
          input.focus();
          return;
        }
        error.classList.add("hidden");
        input.removeAttribute("aria-invalid");
        document.getElementById("success-email").textContent = value;
        form.classList.add("hidden");
        fineprint.classList.add("hidden");
        success.classList.remove("hidden");
        success.focus();
      });
      document.getElementById("reset").addEventListener("click", function () {
        success.classList.add("hidden");
        form.classList.remove("hidden");
        fineprint.classList.remove("hidden");
        input.value = "";
        input.focus();
      });

      // The live transcript line types itself out (skipped for reduced motion).
      var typing = document.getElementById("typing");
      var lines = [
        "Agreed. Pricing can wait for the March release.",
        "I'll draft the beta invite email by Thursday.",
        "Let's review the checklist on Friday's call."
      ];
      if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
        var line = 0, pos = lines[0].length, hold = 40;
        setInterval(function () {
          if (hold > 0) { hold--; return; }
          if (pos >= lines[line].length) { line = (line + 1) % lines.length; pos = 0; }
          pos++;
          typing.textContent = lines[line].slice(0, pos);
          if (pos >= lines[line].length) hold = 45;
        }, 45);
      }
    })();
  </script>
</body>
</html>`;

export const saasWaitlistDemo: DemoParts = {
  title: "Lumen Waitlist Page",
  language: "html",
  code,
  gui: null,
};

# NineTail Studio

A dark-mode builder that turns a prompt into one of three things, with a live preview and the source code side by side:

- **Web UI**: a single HTML page styled with Tailwind, shown in a sandboxed live preview.
- **Desktop GUI (C++ Dear ImGui)**: real `ImGui::Begin()` code plus an interactive HTML replica of the ImGui window, with tabs, sliders, checkboxes, combos, a radar and an overlay.
- **Python (CustomTkinter)**: a runnable `app.py` plus an interactive replica of the CustomTkinter window.

The mascot is a white nine-tailed fox. Its tails sway while idle, flare and pulse one after another while a build is generating, and it flashes a celebration aura when the build is done.

Built with Next.js 14 (App Router), Tailwind CSS, Framer Motion and Lucide icons.

## Run it

```bash
npm install
cp .env.example .env.local   # optional: add keys, see below
npm run dev                  # http://localhost:3000
```

### Demo mode (no keys)

With no keys anywhere, the studio runs in **demo mode**. Builds stream prebuilt example output, and the four Template Vault starters have full showcase builds. Any other prompt gets a clearly labelled demo build. The output panel shows a **Demo** badge so nobody mistakes it for a real AI result.

### Keys

There are two ways to make real AI builds:

1. **Server keys** in `.env.local`:
   - `ANTHROPIC_API_KEY` serves the Claude tails.
   - `OPENROUTER_API_KEY` serves every tail, including DeepSeek and GPT-4o.

   Builds paid with server keys are limited to 8 per visitor IP per 10 minutes. The limit is kept in memory, so on serverless hosting it's best-effort.

   `/api/generate` only accepts JSON requests from the studio's own origin, so other websites can't spend your key through their visitors. Behind a proxy that rewrites the Host header, set `NEXT_PUBLIC_SITE_URL` to the site's public URL.
2. **Bring your own key (BYOK)**: visitors paste an Anthropic (`sk-ant-…`) or OpenRouter (`sk-or-…`) key in the studio.
   - The key is saved in their browser's localStorage.
   - It's sent with each build to `/api/generate`, which passes it to the provider and never stores or logs it.
   - An Anthropic key unlocks the Claude tails; an OpenRouter key unlocks all five.

### The tails (models)

| Tail | Model | Route |
|---|---|---|
| Sonnet (default) | Claude Sonnet 5.5 (`claude-sonnet-5-5`) | Anthropic, or OpenRouter `anthropic/claude-sonnet-5.5` |
| Haiku (Fast) | Claude Haiku 5.5 (`claude-haiku-5-5`) | Anthropic, or OpenRouter |
| Opus (Deepest) | Claude Opus 5.5 (`claude-opus-5-5`) | Anthropic, or OpenRouter |
| DeepSeek | DeepSeek V3.2 (`deepseek/deepseek-v3.2`) | OpenRouter |
| GPT-4o | GPT-4o (`openai/gpt-4o`) | OpenRouter |

Claude 3.7 Sonnet and Claude Sonnet 4 were retired in 2026, so the Claude tails use the current 5.5 models. You can change the list in `lib/models.ts`.

Claude requests go through the official `@anthropic-ai/sdk`:
- They stream, so long builds don't time out.
- The system prompt is marked for prompt caching.
- Sonnet and Opus use Anthropic's server-side refusal fallback.

## Freemium and the paywall

- Every visitor gets **3 free builds ("tails")**. The count is stored in localStorage and shown in the navbar as "Tails Remaining: 3/3".
- When the tails run out, or someone clicks **1-Click ZIP Export**, the upgrade modal opens. It shows:
  - **BYOK Pass**: $19 lifetime or $9/month
  - **NineTail Pro**: $15/month

To take payments, create payment links (for example Stripe Payment Links) and set them in `.env.local`:

```
NEXT_PUBLIC_CHECKOUT_BYOK_LIFETIME_URL=
NEXT_PUBLIC_CHECKOUT_BYOK_MONTHLY_URL=
NEXT_PUBLIC_CHECKOUT_PRO_URL=
```

Until you set them, the buttons say checkout isn't connected yet.

**Important:** the credit counter lives only in the visitor's browser, so anyone can reset it by clearing site data. It is a soft paywall for a demo. A real business also needs:
- accounts,
- a payment webhook that marks a user as paid (for example a Stripe webhook),
- a server-side check of the plan before spending your server key.

`lib/storage.ts` (`usePlan`) is where the paid plan is read today.

## Recording YouTube Shorts

- Set `NEXT_PUBLIC_SHOW_DEMO_RESET=true` to get a **Refill demo tails** button in the upgrade modal, so you can re-record the "out of tails" moment.
- In Chrome DevTools, use device mode at **390 × 844** for a vertical recording. On phones the studio switches to an app layout with a bottom dock and a center Ignite button.
- The Template Vault cards give instant, polished results in demo mode.

## Deploy

Deploy to Vercel (or any Node host): import the repo, set the root directory to `ninetail-studio`, and add the environment variables.

`/api/generate` sets `maxDuration = 300` seconds. If your plan has a lower limit, lower it in `app/api/generate/route.ts`.

## Project layout

```
app/
  page.tsx                 studio page
  api/generate/route.ts    streaming generation endpoint (GET = which server keys exist)
components/
  Studio.tsx               state and layout (desktop split screen, mobile dock)
  KitsuneMascot.tsx        the mascot used everywhere (switch designs here)
  mascot/                  three mascot designs (A is the default)
  Navbar.tsx, UpgradeModal.tsx, Backdrop.tsx
  studio/                  left panel controls, output panel, previews, simulators, code view
lib/
  models.ts                the tails and output targets
  prompts.ts               system prompts per target
  providers/               Anthropic SDK and OpenRouter streaming
  parse.ts                 streaming parser for the <nt-title>/<nt-preview>/<nt-code> format
  useGenerator.ts          client hook that streams a build
  demos/, demo-stream.ts   demo mode output
  storage.ts               tails, key and plan in localStorage
  zip.ts                   1-Click ZIP export
```

### Mascot designs

`components/mascot/` has three designs:
- **A, Celestial Origami** (default)
- **B, Spirit Ink**
- **C, Hero Mascot** (cuter)

To switch, change the import in `components/KitsuneMascot.tsx`.

## How generation works

1. The client posts `{ prompt, target, model, byokKey? }` to `/api/generate`.
2. The server picks a key, builds the system prompt for the target, and streams the model's text back as plain text.
3. The model answers in a small tagged format: `<nt-title>`, then (for desktop targets) `<nt-preview>` with a JSON description of the window, then `<nt-code>` with the full file.
4. The client parses this as it streams:
   - Code appears live.
   - Desktop simulators render as soon as the preview JSON arrives.
   - Web previews load in a sandboxed iframe (scripts allowed, no same-origin access) when the page is complete.

The preview iframe runs on the same page as the studio, so a generated page stuck in an endless loop can freeze the tab until it's reloaded. Fully isolating previews needs a separate preview domain.

"use client";

import { RotateCcw } from "lucide-react";

// Last-resort boundary for the studio route. Previews have their own boundary,
// so this only shows if something outside them fails to render.
export default function Error({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <main className="grid min-h-[100dvh] place-items-center bg-obsidian-950 px-6 text-center">
      <div className="glass max-w-sm rounded-3xl p-7">
        <p className="eyebrow">Spirit core</p>
        <h1 className="mt-2 text-xl font-semibold tracking-tight text-fox-white">The studio hit a snag</h1>
        <p className="mt-2 text-sm text-fox-muted">Something went wrong while rendering. Your tails and key are safe in this browser.</p>
        <button
          type="button"
          onClick={reset}
          className="focus-ring mt-5 inline-flex h-11 items-center gap-2 rounded-xl bg-fox-white px-4 text-sm font-medium text-obsidian-950 transition hover:bg-white"
        >
          <RotateCcw className="h-4 w-4" strokeWidth={1.75} aria-hidden="true" />
          Reload the studio
        </button>
      </div>
    </main>
  );
}

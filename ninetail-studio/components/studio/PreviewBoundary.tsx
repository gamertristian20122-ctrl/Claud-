"use client";

import { Info } from "lucide-react";
import { Component, type ReactNode } from "react";

interface PreviewBoundaryProps {
  /** A new value (the next spec or document) clears a caught error and renders the children again. */
  resetKey: unknown;
  children: ReactNode;
}

/**
 * Catches render errors in previews of untrusted model output (simulators, web
 * preview), so one bad value shows a note instead of unmounting the studio.
 */
export class PreviewBoundary extends Component<PreviewBoundaryProps, { failed: boolean }> {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  componentDidUpdate(prev: PreviewBoundaryProps) {
    if (this.state.failed && !Object.is(prev.resetKey, this.props.resetKey)) this.setState({ failed: false });
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return (
      <div className="relative grid h-full w-full place-items-center rounded-2xl bg-obsidian-950/40 p-4">
        <div className="glass flex max-w-[300px] items-start gap-3 rounded-2xl p-4 text-[13px] text-fox-mist">
          <Info className="mt-0.5 h-4 w-4 shrink-0 text-spirit-violet" strokeWidth={1.75} aria-hidden="true" />
          <p>This preview couldn&apos;t be rendered. See the code tab for the full source.</p>
        </div>
      </div>
    );
  }
}

export default PreviewBoundary;

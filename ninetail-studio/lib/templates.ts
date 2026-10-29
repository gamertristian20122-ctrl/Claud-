import type { Template } from "./types";

// The "UI Remixer / Template Vault": one-click starter builds. Each prompt is
// written as a full design brief, so it works for live generation and also
// maps to a handcrafted demo build in lib/demos (demo mode and recordings).

export const TEMPLATES: Template[] = [
  {
    id: "saas-waitlist",
    name: "SaaS Waitlist Page",
    tagline: "Email capture, countdown, FAQ. Ship it.",
    target: "web",
    icon: "rocket",
    accent: "#a78bfa",
    prompt:
      "A dark, premium waitlist page for Lumen, an AI note-taking app that turns meetings and voice memos into searchable notes. " +
      "Hero with a bold headline, a short subline and an email capture form with an inline success state, next to a mock app window showing a live summary. " +
      "Three feature cards (live transcription, auto-summaries, ask-your-notes search), a three-step how-it-works strip, " +
      "a live countdown to launch day, an FAQ accordion and a minimal footer. Violet accent, glassy cards, mobile-first.",
  },
  {
    id: "imgui-mod-menu",
    name: "C++ ImGui Dark Mod Menu",
    tagline: "Tabbed HUD menu with a live radar",
    target: "imgui",
    icon: "gamepad",
    accent: "#67e8f9",
    prompt:
      "A dark Dear ImGui HUD customization menu for my own game, with a cyan accent and tabs for Visuals, Overlay, Radar and Settings. " +
      "Toggles for the FPS counter, crosshair and minimap radar; sliders for crosshair size, overlay opacity, radar range and zoom; " +
      "an accent color picker, a theme combo, a keybind input, Save config and Reset buttons, a frame-time graph, " +
      "and a live radar widget with a sweep line and blips.",
  },
  {
    id: "link-in-bio",
    name: "Creator Link-in-Bio Store",
    tagline: "Products, cart drawer and newsletter",
    target: "web",
    icon: "store",
    accent: "#f0abfc",
    prompt:
      "A mobile-first link-in-bio store for a lo-fi music producer: a generated initials avatar, a short bio, social links, " +
      "featured product cards (sample packs, presets, a 1:1 feedback session) with prices and Add to cart buttons, " +
      "a slide-up cart drawer with quantities, a bundle discount and totals, and a newsletter signup. Dark with a soft pink accent.",
  },
  {
    id: "gaming-dashboard",
    name: "Gaming Stat Dashboard",
    tagline: "Stat cards, rank chart and match log",
    target: "ctk",
    icon: "chart",
    accent: "#22d3ee",
    prompt:
      "A Python CustomTkinter gaming stats dashboard with a cyan accent: stat cards for K/D, win rate, hours played and rank, " +
      "tabs for Overview, Matches and Settings, a rank-progress line chart drawn on a Canvas, a scrollable recent-matches list with a result filter, " +
      "and settings with switches, sliders, an option menu and a save button.",
  },
];

export function getTemplate(id: Template["id"]): Template | undefined {
  return TEMPLATES.find((t) => t.id === id);
}

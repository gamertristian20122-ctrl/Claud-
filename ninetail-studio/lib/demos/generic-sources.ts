// Source templates for the generic demo builds (see generic-*.ts).
// Each is embedded verbatim with String.raw (no backticks, no "${"). Tokens such
// as __NT_TITLE__ are replaced with per-language escaped values via fill() in util.ts.

export const WEB_TEMPLATE = String.raw`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>__NT_TITLE__ | Demo build</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Sora:wght@400;500;600;700&family=JetBrains+Mono:wght@500&display=swap" rel="stylesheet">
  <script>
    tailwind.config = {
      theme: {
        extend: {
          colors: { ink: { DEFAULT: "#05050a", 900: "#0b0b14", 800: "#121220" } },
          fontFamily: { sans: ["Sora", "ui-sans-serif", "system-ui", "sans-serif"], mono: ["JetBrains Mono", "ui-monospace", "monospace"] }
        }
      }
    };
  </script>
  <style>
    :root { --accent: #a78bfa; --accent-rgb: 167, 139, 250; }
    html, body { background: #05050a; overflow-x: clip; }
    .accent { color: var(--accent); }
    .bg-accent { background: var(--accent); }
    .halo { background: radial-gradient(60% 45% at 50% 0%, rgba(var(--accent-rgb), 0.22), transparent 70%); transition: background .4s; }
    .shimmer { background: linear-gradient(90deg, rgba(255,255,255,.05) 0%, rgba(255,255,255,.12) 50%, rgba(255,255,255,.05) 100%); background-size: 200% 100%; animation: shimmer 1.8s linear infinite; }
    @keyframes shimmer { to { background-position: -200% 0; } }
    @media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation: none !important; transition: none !important; } }
  </style>
</head>
<body class="min-h-screen bg-ink font-sans text-zinc-100 antialiased">
  <div class="pointer-events-none fixed inset-0 halo" aria-hidden="true"></div>

  <div class="relative border-b border-white/10 bg-white/[0.03] px-4 py-2.5 text-center text-[13px] text-zinc-300" role="note">
    <span class="mr-2 inline-block rounded-full border border-white/15 px-2 py-0.5 font-mono text-[11px] uppercase tracking-wider accent">Demo build</span>
    Connect an Anthropic or OpenRouter key to generate this for real.
  </div>

  <header class="relative mx-auto flex max-w-6xl items-center justify-between gap-4 px-5 py-5">
    <a href="#" class="flex min-w-0 items-center gap-2.5 rounded-lg font-semibold tracking-tight focus:outline-none focus-visible:ring-2 focus-visible:ring-white/60">
      <span class="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-accent font-bold text-ink" aria-hidden="true">__NT_INITIAL__</span>
      <span class="truncate">__NT_TITLE__</span>
    </a>
    <a href="#notify" class="shrink-0 rounded-full border border-white/15 px-4 py-2 text-sm font-semibold transition hover:bg-white/10 focus:outline-none focus-visible:ring-2 focus-visible:ring-white/60">Get updates</a>
  </header>

  <main class="relative">
    <section class="mx-auto grid max-w-6xl items-center gap-12 px-5 pb-16 pt-8 sm:pt-14 lg:grid-cols-2">
      <div>
        <p class="font-mono text-xs uppercase tracking-[0.2em] accent">Concept preview</p>
        <h1 class="mt-4 text-4xl font-bold leading-[1.05] tracking-[-0.03em] sm:text-6xl">__NT_TITLE__</h1>
        <figure class="mt-6 rounded-2xl border border-white/10 bg-white/[0.03] p-5">
          <figcaption class="text-xs font-semibold uppercase tracking-[0.16em] text-zinc-400">Your brief</figcaption>
          <blockquote class="mt-2 break-words text-[15px] leading-relaxed text-zinc-200">&ldquo;__NT_PROMPT__&rdquo;</blockquote>
        </figure>
        <div class="mt-7 flex flex-wrap gap-3">
          <a href="#plan" class="inline-flex h-12 items-center rounded-full bg-accent px-6 text-[15px] font-semibold text-ink transition hover:brightness-110 focus:outline-none focus-visible:ring-2 focus-visible:ring-white">See the plan</a>
          <a href="#notify" class="inline-flex h-12 items-center rounded-full border border-white/15 px-6 text-[15px] font-semibold transition hover:bg-white/10 focus:outline-none focus-visible:ring-2 focus-visible:ring-white/60">Get updates</a>
        </div>
      </div>

      <div class="rounded-3xl border border-white/10 bg-ink-900/80 p-4 shadow-2xl backdrop-blur" aria-label="Layout sketch" role="img">
        <div class="flex items-center gap-1.5 pb-3"><span class="h-2.5 w-2.5 rounded-full bg-white/15"></span><span class="h-2.5 w-2.5 rounded-full bg-white/15"></span><span class="h-2.5 w-2.5 rounded-full bg-white/15"></span><span class="ml-3 h-5 flex-1 rounded-md bg-white/[0.06]"></span></div>
        <div class="space-y-3">
          <div class="rounded-2xl border border-white/10 p-4"><p class="font-mono text-[11px] uppercase tracking-wider accent">Hero</p><div class="mt-3 h-5 w-3/4 rounded-md shimmer"></div><div class="mt-2 h-3 w-1/2 rounded-md shimmer"></div><div class="mt-4 h-8 w-28 rounded-full bg-accent opacity-80"></div></div>
          <div class="grid grid-cols-3 gap-3">
            <div class="rounded-2xl border border-white/10 p-3"><div class="h-7 w-7 rounded-lg bg-accent opacity-30"></div><div class="mt-3 h-2.5 rounded shimmer"></div><div class="mt-1.5 h-2.5 w-2/3 rounded shimmer"></div></div>
            <div class="rounded-2xl border border-white/10 p-3"><div class="h-7 w-7 rounded-lg bg-accent opacity-30"></div><div class="mt-3 h-2.5 rounded shimmer"></div><div class="mt-1.5 h-2.5 w-2/3 rounded shimmer"></div></div>
            <div class="rounded-2xl border border-white/10 p-3"><div class="h-7 w-7 rounded-lg bg-accent opacity-30"></div><div class="mt-3 h-2.5 rounded shimmer"></div><div class="mt-1.5 h-2.5 w-2/3 rounded shimmer"></div></div>
          </div>
          <div class="flex items-center justify-between rounded-2xl border border-white/10 p-4"><div class="h-3 w-1/3 rounded shimmer"></div><div class="h-8 w-24 rounded-full border border-white/15"></div></div>
        </div>
      </div>
    </section>

    <section id="plan" class="mx-auto max-w-6xl scroll-mt-6 px-5 py-14">
      <h2 class="text-3xl font-bold tracking-[-0.02em] sm:text-4xl">What the full build includes</h2>
      <div class="mt-8 grid gap-4 md:grid-cols-3">
        <article class="rounded-3xl border border-white/10 bg-white/[0.03] p-6 transition hover:-translate-y-1 hover:border-white/20">
          <p class="font-mono text-sm accent">01</p>
          <h3 class="mt-3 text-lg font-semibold">Layout</h3>
          <p class="mt-2 text-[15px] leading-relaxed text-zinc-400">Sections planned around your brief, responsive from 390&nbsp;px phones to wide desktops.</p>
        </article>
        <article class="rounded-3xl border border-white/10 bg-white/[0.03] p-6 transition hover:-translate-y-1 hover:border-white/20">
          <p class="font-mono text-sm accent">02</p>
          <h3 class="mt-3 text-lg font-semibold">Style</h3>
          <p class="mt-2 text-[15px] leading-relaxed text-zinc-400">A dark, high-contrast look with one accent color. Try a different one below.</p>
        </article>
        <article class="rounded-3xl border border-white/10 bg-white/[0.03] p-6 transition hover:-translate-y-1 hover:border-white/20">
          <p class="font-mono text-sm accent">03</p>
          <h3 class="mt-3 text-lg font-semibold">Interaction</h3>
          <p class="mt-2 text-[15px] leading-relaxed text-zinc-400">Working forms, buttons and menus in plain JavaScript, with no build step.</p>
        </article>
      </div>

      <div class="mt-8 flex flex-wrap items-center gap-4 rounded-3xl border border-white/10 bg-white/[0.03] p-5">
        <p class="text-[15px] font-semibold">Try an accent</p>
        <div class="flex gap-2" role="radiogroup" aria-label="Accent color">
          <button type="button" role="radio" aria-checked="true" aria-label="Violet" data-accent="167,139,250" class="h-11 w-11 rounded-full border-2 border-white bg-[#a78bfa] focus:outline-none focus-visible:ring-2 focus-visible:ring-white/70 focus-visible:ring-offset-2 focus-visible:ring-offset-ink"></button>
          <button type="button" role="radio" aria-checked="false" aria-label="Cyan" data-accent="103,232,249" class="h-11 w-11 rounded-full border-2 border-transparent bg-[#67e8f9] focus:outline-none focus-visible:ring-2 focus-visible:ring-white/70 focus-visible:ring-offset-2 focus-visible:ring-offset-ink"></button>
          <button type="button" role="radio" aria-checked="false" aria-label="Pink" data-accent="240,171,252" class="h-11 w-11 rounded-full border-2 border-transparent bg-[#f0abfc] focus:outline-none focus-visible:ring-2 focus-visible:ring-white/70 focus-visible:ring-offset-2 focus-visible:ring-offset-ink"></button>
          <button type="button" role="radio" aria-checked="false" aria-label="Amber" data-accent="251,191,36" class="h-11 w-11 rounded-full border-2 border-transparent bg-[#fbbf24] focus:outline-none focus-visible:ring-2 focus-visible:ring-white/70 focus-visible:ring-offset-2 focus-visible:ring-offset-ink"></button>
        </div>
      </div>
    </section>

    <section id="notify" class="mx-auto max-w-6xl scroll-mt-6 px-5 pb-20 pt-6">
      <div class="rounded-3xl border border-white/10 bg-gradient-to-br from-white/[0.06] to-transparent p-6 sm:p-10">
        <h2 class="text-2xl font-bold tracking-[-0.02em] sm:text-3xl">Want to hear when it launches?</h2>
        <form id="notify-form" class="mt-5 flex max-w-lg flex-col gap-3 sm:flex-row" novalidate>
          <label for="notify-email" class="sr-only">Email address</label>
          <input id="notify-email" type="email" autocomplete="email" placeholder="you@example.com" class="h-12 w-full rounded-full border border-white/10 bg-ink/60 px-5 text-[15px] placeholder:text-zinc-500 focus:border-white/30 focus:outline-none focus:ring-2 focus:ring-white/20">
          <button type="submit" class="h-12 shrink-0 rounded-full bg-accent px-6 text-[15px] font-semibold text-ink transition hover:brightness-110 focus:outline-none focus-visible:ring-2 focus-visible:ring-white">Notify me</button>
        </form>
        <p id="notify-error" class="mt-2 hidden text-sm text-rose-300" role="alert">Enter a valid email address.</p>
        <p id="notify-success" class="mt-5 hidden text-[15px] font-semibold accent" role="status">Thanks. You're on the list.</p>
      </div>
    </section>
  </main>

  <footer class="relative border-t border-white/10 px-5 py-8 text-center text-[13px] text-zinc-500">
    __NT_TITLE__ &middot; demo build from NineTail Studio
  </footer>

  <script>
    (function () {
      var root = document.documentElement;
      var dots = document.querySelectorAll("[data-accent]");
      dots.forEach(function (dot) {
        dot.addEventListener("click", function () {
          var rgb = dot.getAttribute("data-accent");
          root.style.setProperty("--accent", "rgb(" + rgb + ")");
          root.style.setProperty("--accent-rgb", rgb.split(",").join(", "));
          dots.forEach(function (d) {
            var on = d === dot;
            d.setAttribute("aria-checked", String(on));
            d.classList.toggle("border-white", on);
            d.classList.toggle("border-transparent", !on);
          });
        });
      });

      var form = document.getElementById("notify-form");
      form.addEventListener("submit", function (event) {
        event.preventDefault();
        var input = document.getElementById("notify-email");
        var ok = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(input.value.trim());
        document.getElementById("notify-error").classList.toggle("hidden", ok);
        if (!ok) { input.focus(); return; }
        form.classList.add("hidden");
        document.getElementById("notify-success").classList.remove("hidden");
      });
    })();
  </script>
</body>
</html>`;

export const IMGUI_TEMPLATE = String.raw`// Demo build: a general Dear ImGui settings window themed around your brief.
// Connect an Anthropic or OpenRouter key in NineTail Studio to generate the real thing.
//
// How to use
//   1. Call ninetail::ApplyStyle() once, right after ImGui::CreateContext().
//   2. Call ninetail::RenderUI(&open) every frame, between ImGui::NewFrame() and ImGui::Render().
//
// There is no platform or renderer backend code in this file, so it drops into any
// existing Dear ImGui app (Win32/DX11, GLFW/OpenGL, SDL, ...). Needs Dear ImGui 1.90+
// and C++17. It is UI only: the TODO comments mark where your own logic goes.

#include "imgui.h"

#include <cstdio>

namespace ninetail {
void ApplyStyle();
void RenderUI(bool* p_open);
}  // namespace ninetail

namespace {

const char* const kWindowTitle = "__NT_TITLE__";
const char* const kBrief = "__NT_BRIEF__";

const char* const kModes[] = {"Balanced", "Performance", "Quality"};
const char* const kThemes[] = {"Spirit Night", "Obsidian", "Frost"};
const float kActivity[] = {3, 5, 4, 7, 6, 9, 8, 11, 9, 12, 10, 14, 13, 15};

struct State {
    // General
    bool enabled = true;
    bool show_tooltips = true;
    float intensity = 0.65f;
    int refresh_rate = 60;
    int mode = 0;  // "Balanced"
    char profile[32] = "default";

    // Appearance
    float accent[4] = {0.655f, 0.545f, 0.980f, 1.0f};  // #a78bfa
    int theme = 0;  // "Spirit Night"
    float ui_scale = 1.0f;
    float rounding = 8.0f;
};

State s;
char g_status[64] = "";

ImVec4 Accent(float alpha) { return ImVec4(s.accent[0], s.accent[1], s.accent[2], alpha); }

void ApplyColors() {
    const ImVec4 windows[] = {ImVec4(0.035f, 0.035f, 0.060f, 0.96f), ImVec4(0.020f, 0.020f, 0.024f, 0.97f), ImVec4(0.070f, 0.090f, 0.120f, 0.96f)};
    const ImVec4 frames[] = {ImVec4(0.090f, 0.090f, 0.135f, 1.0f), ImVec4(0.080f, 0.080f, 0.090f, 1.0f), ImVec4(0.120f, 0.150f, 0.195f, 1.0f)};
    const int t = (s.theme >= 0 && s.theme < 3) ? s.theme : 0;

    ImGuiStyle& style = ImGui::GetStyle();
    ImVec4* c = style.Colors;
    c[ImGuiCol_Text] = ImVec4(0.93f, 0.94f, 0.97f, 1.0f);
    c[ImGuiCol_TextDisabled] = ImVec4(0.55f, 0.57f, 0.65f, 1.0f);
    c[ImGuiCol_WindowBg] = windows[t];
    c[ImGuiCol_PopupBg] = ImVec4(windows[t].x, windows[t].y, windows[t].z, 0.98f);
    c[ImGuiCol_Border] = ImVec4(1.0f, 1.0f, 1.0f, 0.08f);
    c[ImGuiCol_FrameBg] = frames[t];
    c[ImGuiCol_FrameBgHovered] = ImVec4(frames[t].x + 0.04f, frames[t].y + 0.04f, frames[t].z + 0.05f, 1.0f);
    c[ImGuiCol_FrameBgActive] = Accent(0.25f);
    c[ImGuiCol_TitleBg] = ImVec4(0.020f, 0.020f, 0.035f, 1.0f);
    c[ImGuiCol_TitleBgActive] = ImVec4(0.030f, 0.030f, 0.055f, 1.0f);
    c[ImGuiCol_CheckMark] = Accent(1.0f);
    c[ImGuiCol_SliderGrab] = Accent(0.85f);
    c[ImGuiCol_SliderGrabActive] = Accent(1.0f);
    c[ImGuiCol_Button] = Accent(0.16f);
    c[ImGuiCol_ButtonHovered] = Accent(0.30f);
    c[ImGuiCol_ButtonActive] = Accent(0.45f);
    c[ImGuiCol_Header] = Accent(0.18f);
    c[ImGuiCol_HeaderHovered] = Accent(0.28f);
    c[ImGuiCol_HeaderActive] = Accent(0.40f);
    c[ImGuiCol_Separator] = ImVec4(1.0f, 1.0f, 1.0f, 0.10f);
    c[ImGuiCol_Tab] = ImVec4(1.0f, 1.0f, 1.0f, 0.04f);
    c[ImGuiCol_TabHovered] = Accent(0.30f);
#if IMGUI_VERSION_NUM >= 19090
    c[ImGuiCol_TabSelected] = Accent(0.22f);
#else
    c[ImGuiCol_TabActive] = Accent(0.22f);
#endif
    c[ImGuiCol_PlotLines] = Accent(1.0f);
    c[ImGuiCol_PlotHistogram] = Accent(0.85f);
}

void ApplyRounding() {
    ImGuiStyle& style = ImGui::GetStyle();
    style.WindowRounding = s.rounding + 4.0f;
    style.FrameRounding = s.rounding;
    style.GrabRounding = s.rounding;
    style.TabRounding = s.rounding;
    style.PopupRounding = s.rounding;
}

void GeneralTab() {
    ImGui::SeparatorText("Behavior");
    ImGui::Checkbox("Enabled", &s.enabled);
    ImGui::Checkbox("Show tooltips", &s.show_tooltips);
    ImGui::SliderFloat("Intensity", &s.intensity, 0.0f, 1.0f, "%.2f");
    ImGui::SliderInt("Refresh rate", &s.refresh_rate, 30, 240, "%d Hz");
    ImGui::Combo("Mode", &s.mode, kModes, IM_ARRAYSIZE(kModes));
    ImGui::InputText("Profile name", s.profile, sizeof(s.profile));
    if (s.show_tooltips && ImGui::IsItemHovered()) ImGui::SetTooltip("Saved settings are stored under this name.");

    ImGui::Spacing();
    if (ImGui::Button("Apply")) {
        // TODO: apply these settings in your app.
        std::snprintf(g_status, sizeof(g_status), "Applied profile \"%s\"", s.profile);
    }
    ImGui::SameLine();
    if (ImGui::Button("Reset")) {
        s = State{};
        ApplyColors();
        ApplyRounding();
        std::snprintf(g_status, sizeof(g_status), "%s", "Defaults restored");
    }
    if (g_status[0] != '\0') ImGui::TextColored(Accent(1.0f), "%s", g_status);
}

void AppearanceTab() {
    ImGui::SeparatorText("Theme");
    if (ImGui::ColorEdit4("Accent", s.accent, ImGuiColorEditFlags_NoInputs | ImGuiColorEditFlags_NoAlpha)) ApplyColors();
    if (ImGui::Combo("Theme", &s.theme, kThemes, IM_ARRAYSIZE(kThemes))) ApplyColors();
    ImGui::SliderFloat("UI scale", &s.ui_scale, 0.75f, 1.5f, "%.2fx");  // TODO: apply to your font setup.
    if (ImGui::SliderFloat("Corner rounding", &s.rounding, 0.0f, 16.0f, "%.0f px")) ApplyRounding();

    ImGui::SeparatorText("Activity");
    ImGui::TextDisabled("Sessions this week");
    ImGui::PlotLines("##activity", kActivity, IM_ARRAYSIZE(kActivity), 0, nullptr, 0.0f, 16.0f, ImVec2(-1.0f, 64.0f));
    ImGui::TextDisabled("Profile completeness");
    ImGui::ProgressBar(0.6f, ImVec2(-1.0f, 0.0f));
}

void BriefTab() {
    ImGui::PushStyleColor(ImGuiCol_Text, ImGui::GetStyleColorVec4(ImGuiCol_TextDisabled));
    ImGui::TextWrapped("%s", "Demo build. Connect an Anthropic or OpenRouter key to generate this for real.");
    ImGui::PopStyleColor();
    ImGui::SeparatorText("Your brief");
    ImGui::TextWrapped("%s", kBrief);
}

}  // namespace

namespace ninetail {

void ApplyStyle() {
    ImGuiStyle& style = ImGui::GetStyle();
    style.WindowPadding = ImVec2(16.0f, 14.0f);
    style.FramePadding = ImVec2(10.0f, 6.0f);
    style.ItemSpacing = ImVec2(10.0f, 8.0f);
    style.WindowBorderSize = 1.0f;
    style.FrameBorderSize = 0.0f;
    style.WindowTitleAlign = ImVec2(0.5f, 0.5f);
    ApplyRounding();
    ApplyColors();
}

void RenderUI(bool* p_open) {
    if (p_open != nullptr && !*p_open) return;

    ImGui::SetNextWindowSize(ImVec2(520.0f, 440.0f), ImGuiCond_FirstUseEver);
    if (ImGui::Begin(kWindowTitle, p_open, ImGuiWindowFlags_NoCollapse)) {
        if (ImGui::BeginTabBar("##tabs")) {
            if (ImGui::BeginTabItem("General")) {
                GeneralTab();
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("Appearance")) {
                AppearanceTab();
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("Brief")) {
                BriefTab();
                ImGui::EndTabItem();
            }
            ImGui::EndTabBar();
        }
    }
    ImGui::End();
}

}  // namespace ninetail`;

export const CTK_TEMPLATE = String.raw`"""
Demo build: a general CustomTkinter app window themed around your brief.
Connect an Anthropic or OpenRouter key in NineTail Studio to generate the real thing.

Run it:
    pip install customtkinter
    python app.py
"""

import tkinter as tk

import customtkinter as ctk

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

WINDOW_TITLE = "__NT_TITLE__"
BRIEF = "__NT_BRIEF__"

ACCENT = "#a78bfa"
ACCENT_DEEP = "#6d28d9"
ACCENT_DEEP_HOVER = "#5b21b6"
BG = "#07070c"
CARD = "#11111b"
CARD_BORDER = "#1f1f2e"
MUTED = "#8b8ba7"
ACTIVITY = [3, 5, 4, 7, 6, 9, 8, 11, 9, 12, 10, 14, 13, 15]


class App(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title(WINDOW_TITLE)
        self.geometry("880x620")
        self.minsize(720, 540)
        self.configure(fg_color=BG)

        # UI state, same defaults as the preview.
        self.view = ctk.StringVar(value="Cards")
        self.dark_mode = ctk.BooleanVar(value=True)
        self.notifications = ctk.BooleanVar(value=True)
        self.start_on_login = ctk.BooleanVar(value=False)
        self.text_size = ctk.DoubleVar(value=14)
        self.volume = ctk.DoubleVar(value=70)
        self.language = ctk.StringVar(value="English")

        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(0, weight=1)
        self.tabs = ctk.CTkTabview(
            self,
            fg_color=BG,
            segmented_button_fg_color=CARD,
            segmented_button_selected_color=ACCENT_DEEP,
            segmented_button_selected_hover_color=ACCENT_DEEP_HOVER,
            segmented_button_unselected_color=CARD,
            segmented_button_unselected_hover_color=CARD_BORDER,
            anchor="nw",
        )
        self.tabs.grid(row=0, column=0, sticky="nsew", padx=18, pady=(8, 18))
        for name in ("Home", "Settings", "Brief"):
            self.tabs.add(name)

        self._build_home(self.tabs.tab("Home"))
        self._build_settings(self.tabs.tab("Settings"))
        self._build_brief(self.tabs.tab("Brief"))

    def _card(self, parent, row, title):
        card = ctk.CTkFrame(parent, corner_radius=16, fg_color=CARD, border_width=1, border_color=CARD_BORDER)
        card.grid(row=row, column=0, sticky="nsew", padx=6, pady=6)
        card.grid_columnconfigure(1, weight=1)
        ctk.CTkLabel(card, text=title, font=ctk.CTkFont(size=15, weight="bold")).grid(
            row=0, column=0, columnspan=3, sticky="w", padx=16, pady=(14, 8)
        )
        return card

    # ------------------------------------------------------------------ Home

    def _build_home(self, tab):
        tab.grid_columnconfigure(0, weight=1)
        tab.grid_rowconfigure(1, weight=1)

        actions = self._card(tab, 0, "Quick actions")
        self.search = ctk.CTkEntry(actions, placeholder_text="Search...", width=240)
        self.search.grid(row=1, column=0, sticky="w", padx=16, pady=(0, 14))
        ctk.CTkSegmentedButton(
            actions,
            values=["Cards", "List"],
            variable=self.view,
            selected_color=ACCENT_DEEP,
            selected_hover_color=ACCENT_DEEP_HOVER,
        ).grid(row=1, column=1, sticky="w", padx=8, pady=(0, 14))
        ctk.CTkButton(actions, text="New item", width=110, fg_color=ACCENT_DEEP, hover_color=ACCENT_DEEP_HOVER, command=self._new_item).grid(
            row=1, column=2, padx=(8, 8), pady=(0, 14)
        )
        ctk.CTkButton(
            actions, text="Import", width=90, fg_color="transparent", border_width=1, border_color=CARD_BORDER, command=self._import
        ).grid(row=1, column=3, padx=(0, 16), pady=(0, 14))
        self.status = ctk.CTkLabel(actions, text="", text_color=MUTED)
        self.status.grid(row=2, column=0, columnspan=4, sticky="w", padx=16, pady=(0, 10))

        activity = self._card(tab, 1, "This week")
        activity.grid_rowconfigure(1, weight=1)
        self.chart = tk.Canvas(activity, bg=CARD, highlightthickness=0, height=180)
        self.chart.grid(row=1, column=0, columnspan=3, sticky="nsew", padx=12, pady=(0, 8))
        self.chart.bind("<Configure>", lambda _event: self._draw_chart())

        ctk.CTkLabel(activity, text="Daily goal", text_color=MUTED).grid(row=2, column=0, sticky="w", padx=16)
        goal = ctk.CTkProgressBar(activity, height=10, progress_color=ACCENT, fg_color=CARD_BORDER)
        goal.grid(row=3, column=0, columnspan=3, sticky="ew", padx=16, pady=(4, 16))
        goal.set(0.62)

    def _draw_chart(self):
        c = self.chart
        c.delete("all")
        w, h = c.winfo_width(), c.winfo_height()
        if w < 60 or h < 60:
            return
        pad = 14
        top = max(ACTIVITY)
        pts = []
        for i, v in enumerate(ACTIVITY):
            pts.append(pad + (w - 2 * pad) * i / (len(ACTIVITY) - 1))
            pts.append(h - pad - (h - 2 * pad) * v / top)
        for i in range(4):
            y = pad + (h - 2 * pad) * i / 3
            c.create_line(pad, y, w - pad, y, fill=CARD_BORDER)
        c.create_line(*pts, fill=ACCENT, width=3, capstyle="round", joinstyle="round")
        c.create_oval(pts[-2] - 6, pts[-1] - 6, pts[-2] + 6, pts[-1] + 6, fill=ACCENT, outline=CARD, width=3)

    def _new_item(self):
        # TODO: create a new item in your app.
        self.status.configure(text="New item created (demo)")

    def _import(self):
        # TODO: open your import flow.
        self.status.configure(text="Import is a TODO in this demo build")

    # ------------------------------------------------------------------ Settings

    def _build_settings(self, tab):
        tab.grid_columnconfigure(0, weight=1)
        card = self._card(tab, 0, "Preferences")
        ctk.CTkSwitch(card, text="Dark mode", variable=self.dark_mode, command=self._toggle_mode, progress_color=ACCENT_DEEP).grid(
            row=1, column=0, columnspan=3, sticky="w", padx=16, pady=6
        )
        ctk.CTkSwitch(card, text="Notifications", variable=self.notifications, progress_color=ACCENT_DEEP).grid(
            row=2, column=0, columnspan=3, sticky="w", padx=16, pady=6
        )
        ctk.CTkCheckBox(
            card, text="Start on login", variable=self.start_on_login, fg_color=ACCENT_DEEP, hover_color=ACCENT_DEEP_HOVER
        ).grid(row=3, column=0, columnspan=3, sticky="w", padx=16, pady=6)

        self._slider(card, "Text size", self.text_size, 10, 22, 12, "{:.0f} px", 4)
        self._slider(card, "Volume", self.volume, 0, 100, 20, "{:.0f}%", 6)

        ctk.CTkLabel(card, text="Language", text_color=MUTED).grid(row=8, column=0, sticky="w", padx=16, pady=6)
        ctk.CTkOptionMenu(
            card,
            values=["English", "Español", "Deutsch", "Français"],
            variable=self.language,
            fg_color=CARD_BORDER,
            button_color=ACCENT_DEEP,
            button_hover_color=ACCENT_DEEP_HOVER,
        ).grid(row=8, column=2, sticky="e", padx=16, pady=6)

        self.saved = ctk.CTkLabel(tab, text="", text_color=MUTED)
        self.saved.grid(row=1, column=0, sticky="w", padx=8, pady=(10, 0))
        ctk.CTkButton(tab, text="Save settings", fg_color=ACCENT_DEEP, hover_color=ACCENT_DEEP_HOVER, command=self._save).grid(
            row=1, column=0, sticky="e", padx=6, pady=(10, 0)
        )

    def _slider(self, parent, text, var, lo, hi, steps, fmt, row):
        ctk.CTkLabel(parent, text=text, text_color=MUTED).grid(row=row, column=0, sticky="w", padx=16, pady=(8, 0))
        value = ctk.CTkLabel(parent, text=fmt.format(var.get()), font=ctk.CTkFont(weight="bold"))
        value.grid(row=row, column=2, sticky="e", padx=16, pady=(8, 0))
        ctk.CTkSlider(
            parent,
            from_=lo,
            to=hi,
            number_of_steps=steps,
            variable=var,
            command=lambda v: value.configure(text=fmt.format(float(v))),
            progress_color=ACCENT_DEEP,
            button_color=ACCENT,
            button_hover_color=ACCENT_DEEP_HOVER,
        ).grid(row=row + 1, column=0, columnspan=3, sticky="ew", padx=16, pady=(4, 8))

    def _toggle_mode(self):
        ctk.set_appearance_mode("dark" if self.dark_mode.get() else "light")

    def _save(self):
        # TODO: persist the settings with your own storage.
        self.saved.configure(text="Settings saved")

    # ------------------------------------------------------------------ Brief

    def _build_brief(self, tab):
        tab.grid_columnconfigure(0, weight=1)
        tab.grid_rowconfigure(2, weight=1)
        ctk.CTkLabel(
            tab,
            text="Demo build. Connect an Anthropic or OpenRouter key to generate this for real.",
            text_color=MUTED,
            anchor="w",
        ).grid(row=0, column=0, sticky="ew", padx=8, pady=(4, 8))
        ctk.CTkLabel(tab, text="Your brief", font=ctk.CTkFont(size=15, weight="bold"), anchor="w").grid(
            row=1, column=0, sticky="ew", padx=8
        )
        box = ctk.CTkTextbox(tab, wrap="word", fg_color=CARD, border_width=1, border_color=CARD_BORDER, corner_radius=14)
        box.grid(row=2, column=0, sticky="nsew", padx=6, pady=(6, 4))
        box.insert("0.0", BRIEF)
        box.configure(state="disabled")


if __name__ == "__main__":
    App().mainloop()`;


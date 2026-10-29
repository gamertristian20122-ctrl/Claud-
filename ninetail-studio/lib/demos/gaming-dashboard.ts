// Demo build for the "Gaming Stat Dashboard" template: a CustomTkinter dashboard.
// The GuiSpec below mirrors the Python exactly (title, tabs, labels, defaults).
// The source is embedded verbatim with String.raw (it contains no backticks and
// no "${"), so `code` is exactly the file the studio shows and exports.

import type { GuiSpec, GuiWidget } from "../types";
import type { DemoParts } from "./util";

const code = String.raw`"""
Gaming Stat Dashboard: a dark CustomTkinter dashboard for your match stats.

Overview shows headline stats and a rank-progress chart, Matches lists recent
games with a result filter, and Settings holds the dashboard preferences.

Run it:
    pip install customtkinter
    python app.py
"""

import tkinter as tk

import customtkinter as ctk

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

ACCENT = "#22d3ee"
ACCENT_DEEP = "#0e7490"
ACCENT_DEEP_HOVER = "#155e75"
ACCENT_FILL = "#0b2a33"
BG = "#07080d"
CARD = "#10131c"
CARD_BORDER = "#1d2433"
GRID = "#1a2030"
MUTED = "#8b93a7"
WIN = "#4ade80"
LOSS = "#f87171"

STATS = [
    ("K/D Ratio", "1.42", "+0.08"),
    ("Win Rate", "54.6%", "+2.1%"),
    ("Hours Played", "312 h", "+9 h"),
    ("Rank", "Diamond II", "+86 RP"),
]

# Rank rating after each of the last 20 matches. TODO: load from your stats source.
RANK_HISTORY = [
    2310, 2335, 2318, 2352, 2371, 2360, 2394, 2412, 2398, 2431,
    2455, 2440, 2468, 2490, 2476, 2502, 2525, 2511, 2548, 2566,
]
TIERS = [(2400, "Diamond II"), (2600, "Diamond I")]

# (result, map, mode, kills, deaths, assists, rank points, duration)
MATCHES = [
    ("Win", "Harbor", "Ranked", 24, 11, 6, "+21", "31:12"),
    ("Win", "Skyline", "Ranked", 19, 14, 9, "+18", "28:40"),
    ("Loss", "Foundry", "Ranked", 12, 17, 4, "-16", "24:05"),
    ("Win", "Harbor", "Ranked", 27, 9, 3, "+23", "33:51"),
    ("Win", "Lumen Yard", "Ranked", 16, 12, 11, "+17", "29:18"),
    ("Loss", "Skyline", "Ranked", 14, 18, 7, "-14", "26:47"),
    ("Win", "Foundry", "Ranked", 21, 13, 5, "+20", "30:02"),
    ("Loss", "Lumen Yard", "Ranked", 9, 15, 12, "-15", "22:39"),
    ("Win", "Harbor", "Ranked", 22, 10, 8, "+22", "32:26"),
    ("Win", "Skyline", "Ranked", 18, 12, 6, "+19", "27:55"),
]


def smooth_points(points, steps):
    """Catmull-Rom curve through (x, y) points. steps=0 keeps straight segments."""
    if steps <= 0 or len(points) < 3:
        return points
    padded = [points[0], *points, points[-1]]
    out = []
    for i in range(1, len(padded) - 2):
        p0, p1, p2, p3 = padded[i - 1], padded[i], padded[i + 1], padded[i + 2]
        for s in range(steps):
            t = s / steps
            out.append(tuple(
                0.5 * (2 * p1[k] + (p2[k] - p0[k]) * t
                       + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t * t
                       + (3 * p1[k] - p0[k] - 3 * p2[k] + p3[k]) * t * t * t)
                for k in (0, 1)
            ))
    out.append(points[-1])
    return out


class StatCard(ctk.CTkFrame):
    """A headline number with its weekly change."""

    def __init__(self, master, label, value, delta):
        super().__init__(master, corner_radius=16, fg_color=CARD, border_width=1, border_color=CARD_BORDER)
        ctk.CTkLabel(self, text=label.upper(), font=ctk.CTkFont(size=11, weight="bold"), text_color=MUTED).pack(
            anchor="w", padx=16, pady=(14, 0)
        )
        self.value = ctk.CTkLabel(self, text=value, font=ctk.CTkFont(size=26, weight="bold"))
        self.value.pack(anchor="w", padx=16)
        ctk.CTkLabel(
            self,
            text=delta + " this week",
            font=ctk.CTkFont(size=12),
            text_color=WIN if delta.startswith("+") else LOSS,
        ).pack(anchor="w", padx=16, pady=(0, 14))

    def set_compact(self, compact):
        self.value.configure(font=ctk.CTkFont(size=20 if compact else 26, weight="bold"))


class App(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Gaming Stat Dashboard")
        self.geometry("1000x700")
        self.minsize(860, 620)
        self.configure(fg_color=BG)

        # UI state, same defaults as the preview.
        self.result_filter = ctk.StringVar(value="All")
        self.player_tag = ctk.StringVar(value="NineTail#0420")
        self.region = ctk.StringVar(value="EU West")
        self.auto_refresh = ctk.BooleanVar(value=True)
        self.show_tiers = ctk.BooleanVar(value=True)
        self.compact_cards = ctk.BooleanVar(value=False)
        self.refresh_interval = ctk.DoubleVar(value=15)
        self.chart_smoothing = ctk.DoubleVar(value=40)
        self.notify_rank_up = ctk.BooleanVar(value=True)

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
        for name in ("Overview", "Matches", "Settings"):
            self.tabs.add(name)

        self._build_overview(self.tabs.tab("Overview"))
        self._build_matches(self.tabs.tab("Matches"))
        self._build_settings(self.tabs.tab("Settings"))

    # ------------------------------------------------------------------ Overview

    def _build_overview(self, tab):
        tab.grid_columnconfigure((0, 1, 2, 3), weight=1, uniform="stats")
        tab.grid_rowconfigure(1, weight=1)

        self.cards = []
        for col, (label, value, delta) in enumerate(STATS):
            card = StatCard(tab, label, value, delta)
            card.grid(row=0, column=col, sticky="nsew", padx=6, pady=(4, 12))
            self.cards.append(card)

        chart_card = ctk.CTkFrame(tab, corner_radius=16, fg_color=CARD, border_width=1, border_color=CARD_BORDER)
        chart_card.grid(row=1, column=0, columnspan=4, sticky="nsew", padx=6, pady=(0, 12))
        chart_card.grid_columnconfigure(0, weight=1)
        chart_card.grid_rowconfigure(1, weight=1)
        ctk.CTkLabel(
            chart_card, text="Rank rating · last 20 matches", font=ctk.CTkFont(size=14, weight="bold")
        ).grid(row=0, column=0, sticky="w", padx=18, pady=(14, 0))

        self.chart_font = ctk.CTkFont(size=11)
        self.chart = tk.Canvas(chart_card, bg=CARD, highlightthickness=0, height=240)
        self.chart.grid(row=1, column=0, sticky="nsew", padx=12, pady=(4, 12))
        self.chart.bind("<Configure>", lambda _event: self._draw_chart())

        progress_card = ctk.CTkFrame(tab, corner_radius=16, fg_color=CARD, border_width=1, border_color=CARD_BORDER)
        progress_card.grid(row=2, column=0, columnspan=4, sticky="ew", padx=6, pady=(0, 4))
        progress_card.grid_columnconfigure(0, weight=1)
        ctk.CTkLabel(progress_card, text="Season progress", font=ctk.CTkFont(size=14, weight="bold")).grid(
            row=0, column=0, sticky="w", padx=18, pady=(14, 6)
        )
        ctk.CTkLabel(progress_card, text="68% to Diamond I", text_color=MUTED).grid(
            row=0, column=1, sticky="e", padx=18, pady=(14, 6)
        )
        progress = ctk.CTkProgressBar(progress_card, height=10, corner_radius=5, progress_color=ACCENT, fg_color=GRID)
        progress.grid(row=1, column=0, columnspan=2, sticky="ew", padx=18, pady=(0, 18))
        progress.set(0.68)

    def _draw_chart(self):
        c = self.chart
        c.delete("all")
        w, h = c.winfo_width(), c.winfo_height()
        if w < 80 or h < 80:
            return
        left, right, top, bottom = 52, 20, 16, 16
        lo, hi = 2250, 2650

        def point(i, v):
            x = left + (w - left - right) * i / (len(RANK_HISTORY) - 1)
            y = top + (h - top - bottom) * (1 - (v - lo) / (hi - lo))
            return x, y

        for v in range(2300, hi + 1, 100):
            _, y = point(0, v)
            c.create_line(left, y, w - right, y, fill=GRID)
            c.create_text(left - 10, y, text=str(v), anchor="e", fill=MUTED, font=self.chart_font)

        points = smooth_points([point(i, v) for i, v in enumerate(RANK_HISTORY)], int(self.chart_smoothing.get() / 10))
        coords = [n for xy in points for n in xy]
        c.create_polygon(left, h - bottom, *coords, w - right, h - bottom, fill=ACCENT_FILL, outline="")

        if self.show_tiers.get():
            for v, name in TIERS:
                _, y = point(0, v)
                c.create_line(left, y, w - right, y, fill=ACCENT_DEEP, dash=(5, 4))
                c.create_text(left + 8, y - 10, text=name, anchor="w", fill=ACCENT, font=self.chart_font)

        c.create_line(*coords, fill=ACCENT, width=3, capstyle="round", joinstyle="round")
        x, y = coords[-2], coords[-1]
        c.create_oval(x - 7, y - 7, x + 7, y + 7, fill=ACCENT, outline=CARD, width=3)
        c.create_text(x - 14, y - 14, text=str(RANK_HISTORY[-1]), anchor="e", fill="#e6fbff", font=self.chart_font)

    # ------------------------------------------------------------------ Matches

    def _build_matches(self, tab):
        tab.grid_columnconfigure(0, weight=1)
        tab.grid_rowconfigure(1, weight=1)

        bar = ctk.CTkFrame(tab, fg_color="transparent")
        bar.grid(row=0, column=0, sticky="ew", padx=6, pady=(4, 10))
        bar.grid_columnconfigure(1, weight=1)
        ctk.CTkLabel(bar, text="Show", text_color=MUTED).grid(row=0, column=0, padx=(0, 10))
        ctk.CTkSegmentedButton(
            bar,
            values=["All", "Wins", "Losses"],
            variable=self.result_filter,
            command=lambda _value: self._render_matches(),
            selected_color=ACCENT_DEEP,
            selected_hover_color=ACCENT_DEEP_HOVER,
        ).grid(row=0, column=1, sticky="w")
        self.match_status = ctk.CTkLabel(bar, text="", text_color=MUTED)
        self.match_status.grid(row=0, column=2, padx=12)
        ctk.CTkButton(
            bar,
            text="Refresh matches",
            width=150,
            fg_color=ACCENT,
            hover_color="#67e8f9",
            text_color="#04131a",
            command=self._refresh_matches,
        ).grid(row=0, column=3)

        self.match_list = ctk.CTkScrollableFrame(tab, fg_color=BG, corner_radius=0)
        self.match_list.grid(row=1, column=0, sticky="nsew", padx=0, pady=(0, 4))
        self.match_list.grid_columnconfigure(0, weight=1)
        self.bold = ctk.CTkFont(size=14, weight="bold")
        self._render_matches()

    def _render_matches(self):
        for child in self.match_list.winfo_children():
            child.destroy()
        wanted = self.result_filter.get()
        rows = [m for m in MATCHES if wanted == "All" or (wanted == "Wins") == (m[0] == "Win")]
        for i, (result, map_name, mode, kills, deaths, assists, rp, duration) in enumerate(rows):
            won = result == "Win"
            row = ctk.CTkFrame(self.match_list, corner_radius=12, fg_color=CARD, border_width=1, border_color=CARD_BORDER)
            row.grid(row=i, column=0, sticky="ew", padx=6, pady=4)
            row.grid_columnconfigure(1, weight=1)
            ctk.CTkLabel(
                row,
                text="W" if won else "L",
                width=36,
                height=36,
                corner_radius=10,
                fg_color="#0f2e22" if won else "#3a1518",
                text_color=WIN if won else LOSS,
                font=self.bold,
            ).grid(row=0, column=0, rowspan=2, padx=12, pady=10)
            ctk.CTkLabel(row, text=map_name, font=self.bold, anchor="w").grid(row=0, column=1, sticky="w", pady=(10, 0))
            ctk.CTkLabel(row, text=mode + "  ·  " + duration, text_color=MUTED, anchor="w").grid(
                row=1, column=1, sticky="w", pady=(0, 10)
            )
            ctk.CTkLabel(row, text=f"{kills} / {deaths} / {assists}", font=self.bold).grid(
                row=0, column=2, rowspan=2, padx=16
            )
            ctk.CTkLabel(
                row, text=rp + " RP", width=70, anchor="e", text_color=WIN if rp.startswith("+") else LOSS, font=self.bold
            ).grid(row=0, column=3, rowspan=2, padx=(0, 16))

    def _refresh_matches(self):
        # TODO: pull the latest matches from your stats source, then call self._render_matches().
        self.match_status.configure(text="Up to date")

    # ------------------------------------------------------------------ Settings

    def _build_settings(self, tab):
        tab.grid_columnconfigure((0, 1), weight=1, uniform="settings")

        profile = self._section(tab, "Profile", 0)
        self._row_label(profile, "Player tag", 1)
        ctk.CTkEntry(profile, textvariable=self.player_tag, placeholder_text="Name#0000", width=220).grid(
            row=1, column=1, sticky="e", padx=16, pady=6
        )
        self._row_label(profile, "Region", 2)
        ctk.CTkOptionMenu(
            profile,
            values=["EU West", "NA East", "NA West", "Asia Pacific"],
            variable=self.region,
            width=220,
            fg_color=CARD_BORDER,
            button_color=ACCENT_DEEP,
            button_hover_color=ACCENT_DEEP_HOVER,
        ).grid(row=2, column=1, sticky="e", padx=16, pady=6)
        ctk.CTkCheckBox(
            profile,
            text="Notify me on rank up",
            variable=self.notify_rank_up,
            fg_color=ACCENT_DEEP,
            hover_color=ACCENT_DEEP_HOVER,
        ).grid(row=3, column=0, columnspan=2, sticky="w", padx=16, pady=(10, 16))

        dash = self._section(tab, "Dashboard", 1)
        switches = [
            ("Auto-refresh stats", self.auto_refresh, None),
            ("Show tier lines on chart", self.show_tiers, self._draw_chart),
            ("Compact stat cards", self.compact_cards, self._apply_compact),
        ]
        for i, (text, var, command) in enumerate(switches, start=1):
            ctk.CTkSwitch(dash, text=text, variable=var, command=command, progress_color=ACCENT_DEEP).grid(
                row=i, column=0, columnspan=2, sticky="w", padx=16, pady=6
            )

        self.interval_label = self._slider(dash, "Refresh interval", self.refresh_interval, 5, 60, 11, "{:.0f} s", 4)
        self.smoothing_label = self._slider(dash, "Chart smoothing", self.chart_smoothing, 0, 100, 20, "{:.0f}%", 6)

        footer = ctk.CTkFrame(tab, fg_color="transparent")
        footer.grid(row=1, column=0, columnspan=2, sticky="ew", padx=6, pady=(14, 4))
        footer.grid_columnconfigure(0, weight=1)
        self.status = ctk.CTkLabel(footer, text="", text_color=MUTED)
        self.status.grid(row=0, column=0, sticky="w")
        ctk.CTkButton(
            footer,
            text="Save settings",
            width=160,
            height=38,
            fg_color=ACCENT,
            hover_color="#67e8f9",
            text_color="#04131a",
            font=ctk.CTkFont(size=14, weight="bold"),
            command=self._save_settings,
        ).grid(row=0, column=1, sticky="e")

    def _section(self, tab, title, column):
        frame = ctk.CTkFrame(tab, corner_radius=16, fg_color=CARD, border_width=1, border_color=CARD_BORDER)
        frame.grid(row=0, column=column, sticky="nsew", padx=6, pady=(4, 0))
        frame.grid_columnconfigure(1, weight=1)
        ctk.CTkLabel(frame, text=title, font=ctk.CTkFont(size=15, weight="bold")).grid(
            row=0, column=0, columnspan=2, sticky="w", padx=16, pady=(14, 6)
        )
        return frame

    def _row_label(self, parent, text, row):
        ctk.CTkLabel(parent, text=text, text_color=MUTED).grid(row=row, column=0, sticky="w", padx=16, pady=6)

    def _slider(self, parent, text, var, lo, hi, steps, fmt, row):
        self._row_label(parent, text, row)
        value = ctk.CTkLabel(parent, text=fmt.format(var.get()), font=ctk.CTkFont(weight="bold"))
        value.grid(row=row, column=1, sticky="e", padx=16)

        def changed(v):
            value.configure(text=fmt.format(float(v)))
            if var is self.chart_smoothing:
                self._draw_chart()

        ctk.CTkSlider(
            parent,
            from_=lo,
            to=hi,
            number_of_steps=steps,
            variable=var,
            command=changed,
            progress_color=ACCENT_DEEP,
            button_color=ACCENT,
            button_hover_color="#67e8f9",
        ).grid(row=row + 1, column=0, columnspan=2, sticky="ew", padx=16, pady=(0, 10))
        return value

    def _apply_compact(self):
        for card in self.cards:
            card.set_compact(self.compact_cards.get())

    def _save_settings(self):
        # TODO: persist these values with your own settings store.
        self.status.configure(text="Saved settings for " + self.player_tag.get())


if __name__ == "__main__":
    App().mainloop()`;

/** Mirrors RANK_HISTORY and MATCHES in the Python source above. */
const RANK_HISTORY = [2310, 2335, 2318, 2352, 2371, 2360, 2394, 2412, 2398, 2431, 2455, 2440, 2468, 2490, 2476, 2502, 2525, 2511, 2548, 2566];
const MATCHES: [string, string, string, number, number, number, string, string][] = [
  ["Win", "Harbor", "Ranked", 24, 11, 6, "+21", "31:12"],
  ["Win", "Skyline", "Ranked", 19, 14, 9, "+18", "28:40"],
  ["Loss", "Foundry", "Ranked", 12, 17, 4, "-16", "24:05"],
  ["Win", "Harbor", "Ranked", 27, 9, 3, "+23", "33:51"],
  ["Win", "Lumen Yard", "Ranked", 16, 12, 11, "+17", "29:18"],
  ["Loss", "Skyline", "Ranked", 14, 18, 7, "-14", "26:47"],
  ["Win", "Foundry", "Ranked", 21, 13, 5, "+20", "30:02"],
  ["Loss", "Lumen Yard", "Ranked", 9, 15, 12, "-15", "22:39"],
  ["Win", "Harbor", "Ranked", 22, 10, 8, "+22", "32:26"],
  ["Win", "Skyline", "Ranked", 18, 12, 6, "+19", "27:55"],
];

const gui: GuiSpec = {
  title: "Gaming Stat Dashboard",
  width: 1000,
  height: 700,
  accent: "#22d3ee",
  tabs: [
    {
      label: "Overview",
      widgets: [
        { type: "stat", label: "K/D Ratio", value: "1.42", delta: "+0.08" },
        { type: "stat", label: "Win Rate", value: "54.6%", delta: "+2.1%", sameLine: true },
        { type: "stat", label: "Hours Played", value: "312 h", delta: "+9 h", sameLine: true },
        { type: "stat", label: "Rank", value: "Diamond II", delta: "+86 RP", sameLine: true },
        { type: "plot", label: "Rank rating · last 20 matches", points: RANK_HISTORY, min: 2250, max: 2650 },
        { type: "progress", label: "Season progress", value: 0.68 },
        { type: "text", label: "68% to Diamond I" },
      ],
    },
    {
      label: "Matches",
      widgets: [
        { type: "radio", label: "Show", options: ["All", "Wins", "Losses"], value: "All" },
        { type: "button", label: "Refresh matches", sameLine: true },
        ...MATCHES.map(([result, map, mode, k, d, a, rp, duration]): GuiWidget => ({
          type: "text",
          label: `${result} · ${map} · ${mode} · ${k} / ${d} / ${a} · ${rp} RP · ${duration}`,
        })),
      ],
    },
    {
      label: "Settings",
      widgets: [
        { type: "separator", label: "Profile" },
        { type: "input", label: "Player tag", value: "NineTail#0420", placeholder: "Name#0000" },
        { type: "combo", label: "Region", options: ["EU West", "NA East", "NA West", "Asia Pacific"], value: "EU West" },
        { type: "checkbox", label: "Notify me on rank up", value: true },
        { type: "separator", label: "Dashboard" },
        { type: "toggle", label: "Auto-refresh stats", value: true },
        { type: "toggle", label: "Show tier lines on chart", value: true },
        { type: "toggle", label: "Compact stat cards", value: false },
        { type: "slider", label: "Refresh interval", value: 15, min: 5, max: 60, format: "%d s" },
        { type: "slider", label: "Chart smoothing", value: 40, min: 0, max: 100, format: "%d%%" },
        { type: "button", label: "Save settings" },
      ],
    },
  ],
};

export const gamingDashboardDemo: DemoParts = {
  title: "Gaming Stat Dashboard",
  language: "python",
  code,
  gui,
};

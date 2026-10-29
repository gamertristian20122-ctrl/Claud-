// Demo build for the "C++ ImGui Dark Mod Menu" template: a HUD customization menu
// for your own game. The GuiSpec below mirrors the C++ exactly (titles, tabs,
// labels, defaults); radar blips use +x right, +y down.
// The source is embedded verbatim with String.raw (it contains no backticks and
// no "${"), so `code` is exactly the file the studio shows and exports.

import type { GuiSpec } from "../types";
import type { DemoParts } from "./util";

const code = String.raw`// NineTail HUD Menu: a dark, tabbed Dear ImGui menu for customizing your own game's HUD.
//
// How to use
//   1. Call ninetail::ApplyStyle() once, right after ImGui::CreateContext().
//   2. Call ninetail::RenderUI(&open) every frame, between ImGui::NewFrame() and ImGui::Render().
//
// There is no platform or renderer backend code in this file, so it drops into any
// existing Dear ImGui app (Win32/DX11, GLFW/OpenGL, SDL, ...). Needs Dear ImGui 1.90+
// and C++17. It is UI only: hook the TODO spots up to your game's own settings.

#include "imgui.h"

#include <cmath>
#include <cstdio>
#include <cstring>

namespace ninetail {
void ApplyStyle();
void RenderUI(bool* p_open);
}  // namespace ninetail

namespace {

constexpr float kPi = 3.14159265358979f;

const char* const kCrosshairStyles[] = {"Cross", "Dot", "Circle", "T-shape"};
const char* const kOverlayCorners[] = {"Top left", "Top right", "Bottom left", "Bottom right"};
const char* const kThemes[] = {"Spirit Night", "Obsidian", "Frost"};

enum BlipKind { Ally, Enemy, Objective };

struct Blip {
    float x, y;  // -1..1 around the player at zoom 1.0 (+x right, +y down)
    BlipKind kind;
};

// Sample minimap contacts. TODO: feed these from your game's entity list.
const Blip kBlips[] = {
    {0.32f, -0.46f, Ally},  {-0.38f, -0.18f, Ally},   {0.56f, 0.28f, Enemy},
    {-0.22f, 0.60f, Enemy}, {0.70f, -0.12f, Enemy},   {-0.08f, -0.78f, Objective},
};

struct MenuState {
    // Visuals
    bool show_fps = true;
    bool show_crosshair = true;
    bool show_radar = true;
    int crosshair_style = 0;  // "Cross"
    float crosshair_size = 12.0f;
    float crosshair_gap = 4.0f;
    float crosshair_color[4] = {0.404f, 0.910f, 0.976f, 1.0f};  // #67e8f9

    // Overlay
    int overlay_opacity = 85;  // percent
    int overlay_corner = 1;    // "Top right"
    float hud_scale = 1.0f;
    bool show_watermark = true;
    char watermark[32] = "NINETAIL";

    // Radar
    float radar_range = 150.0f;  // meters
    float radar_zoom = 1.0f;
    bool radar_rotate = true;
    bool radar_objectives = true;

    // Settings
    int theme = 0;  // "Spirit Night"
    float accent[4] = {0.404f, 0.910f, 0.976f, 1.0f};  // #67e8f9
    char keybind[16] = "INSERT";
    bool pause_on_open = false;
    char config_name[32] = "default";
};

MenuState g;
char g_status[64] = "";
float g_frame_ms[90] = {};
int g_frame_head = 0;

ImVec4 Rgba(float r, float g_, float b, float a = 1.0f) { return ImVec4(r, g_, b, a); }
ImVec4 Accent(float alpha) { return ImVec4(g.accent[0], g.accent[1], g.accent[2], alpha); }
ImU32 AccentU32(float alpha) { return ImGui::ColorConvertFloat4ToU32(Accent(alpha)); }

// Rebuilds every color from the chosen theme and accent. Safe to call any frame.
void ApplyColors() {
    struct Base { ImVec4 window, frame, text; };
    const Base bases[] = {
        {Rgba(0.035f, 0.035f, 0.060f, 0.96f), Rgba(0.090f, 0.090f, 0.135f), Rgba(0.93f, 0.94f, 0.97f)},  // Spirit Night
        {Rgba(0.020f, 0.020f, 0.024f, 0.97f), Rgba(0.080f, 0.080f, 0.090f), Rgba(0.90f, 0.90f, 0.90f)},  // Obsidian
        {Rgba(0.070f, 0.090f, 0.120f, 0.96f), Rgba(0.120f, 0.150f, 0.195f), Rgba(0.94f, 0.97f, 1.00f)},  // Frost
    };
    const Base& b = bases[(g.theme >= 0 && g.theme < 3) ? g.theme : 0];
    ImVec4* c = ImGui::GetStyle().Colors;

    c[ImGuiCol_Text] = b.text;
    c[ImGuiCol_TextDisabled] = Rgba(0.55f, 0.57f, 0.65f);
    c[ImGuiCol_WindowBg] = b.window;
    c[ImGuiCol_ChildBg] = Rgba(1.0f, 1.0f, 1.0f, 0.02f);
    c[ImGuiCol_PopupBg] = Rgba(b.window.x, b.window.y, b.window.z, 0.98f);
    c[ImGuiCol_Border] = Rgba(1.0f, 1.0f, 1.0f, 0.08f);
    c[ImGuiCol_FrameBg] = b.frame;
    c[ImGuiCol_FrameBgHovered] = Rgba(b.frame.x + 0.04f, b.frame.y + 0.04f, b.frame.z + 0.05f);
    c[ImGuiCol_FrameBgActive] = Accent(0.25f);
    c[ImGuiCol_TitleBg] = Rgba(0.020f, 0.020f, 0.035f);
    c[ImGuiCol_TitleBgActive] = Rgba(0.030f, 0.030f, 0.055f);
    c[ImGuiCol_TitleBgCollapsed] = Rgba(0.020f, 0.020f, 0.035f, 0.80f);
    c[ImGuiCol_CheckMark] = Accent(1.0f);
    c[ImGuiCol_SliderGrab] = Accent(0.85f);
    c[ImGuiCol_SliderGrabActive] = Accent(1.0f);
    c[ImGuiCol_Button] = Accent(0.16f);
    c[ImGuiCol_ButtonHovered] = Accent(0.30f);
    c[ImGuiCol_ButtonActive] = Accent(0.45f);
    c[ImGuiCol_Header] = Accent(0.18f);
    c[ImGuiCol_HeaderHovered] = Accent(0.28f);
    c[ImGuiCol_HeaderActive] = Accent(0.40f);
    c[ImGuiCol_Separator] = Rgba(1.0f, 1.0f, 1.0f, 0.10f);
    c[ImGuiCol_Tab] = Rgba(1.0f, 1.0f, 1.0f, 0.04f);
    c[ImGuiCol_TabHovered] = Accent(0.30f);
#if IMGUI_VERSION_NUM >= 19090
    c[ImGuiCol_TabSelected] = Accent(0.22f);
#else
    c[ImGuiCol_TabActive] = Accent(0.22f);
#endif
    c[ImGuiCol_PlotLines] = Accent(1.0f);
    c[ImGuiCol_PlotLinesHovered] = Rgba(1.0f, 1.0f, 1.0f);
    c[ImGuiCol_PlotHistogram] = Accent(0.85f);
    c[ImGuiCol_ResizeGrip] = Accent(0.12f);
    c[ImGuiCol_ResizeGripHovered] = Accent(0.40f);
    c[ImGuiCol_ResizeGripActive] = Accent(0.70f);
    c[ImGuiCol_TextSelectedBg] = Accent(0.30f);
}

// The live minimap: rings, cross lines, a sweep line and contacts.
void DrawRadar(float size) {
    ImDrawList* dl = ImGui::GetWindowDrawList();
    const ImVec2 origin = ImGui::GetCursorScreenPos();
    const ImVec2 c(origin.x + size * 0.5f, origin.y + size * 0.5f);
    const float r = size * 0.5f - 4.0f;
    const float t = static_cast<float>(ImGui::GetTime());

    dl->AddCircleFilled(c, r, IM_COL32(8, 12, 20, 235), 64);
    for (int i = 1; i <= 3; ++i) dl->AddCircle(c, r * static_cast<float>(i) / 3.0f, AccentU32(0.18f), 64, 1.0f);
    dl->AddLine(ImVec2(c.x - r, c.y), ImVec2(c.x + r, c.y), AccentU32(0.18f), 1.0f);
    dl->AddLine(ImVec2(c.x, c.y - r), ImVec2(c.x, c.y + r), AccentU32(0.18f), 1.0f);

    // Sweep line with a soft wedge trailing behind it.
    const float sweep = std::fmod(t * 1.8f, 2.0f * kPi);
    dl->PathLineTo(c);
    dl->PathArcTo(c, r, sweep - 0.6f, sweep, 24);
    dl->PathFillConvex(AccentU32(0.12f));
    dl->AddLine(c, ImVec2(c.x + std::cos(sweep) * r, c.y + std::sin(sweep) * r), AccentU32(0.95f), 2.0f);

    // TODO: use your player's real yaw here.
    const float heading = g.radar_rotate ? 0.35f * std::sin(t * 0.4f) : 0.0f;
    const float cs = std::cos(heading), sn = std::sin(heading);
    for (const Blip& b : kBlips) {
        if (b.kind == Objective && !g.radar_objectives) continue;
        const float x = (b.x * cs - b.y * sn) * g.radar_zoom;
        const float y = (b.x * sn + b.y * cs) * g.radar_zoom;
        if (x * x + y * y > 0.92f) continue;  // outside the radar at this zoom
        const ImVec2 p(c.x + x * r, c.y + y * r);
        if (b.kind == Objective) {
            dl->AddQuadFilled(ImVec2(p.x, p.y - 6), ImVec2(p.x + 6, p.y), ImVec2(p.x, p.y + 6), ImVec2(p.x - 6, p.y), IM_COL32(251, 191, 36, 255));
        } else {
            const bool ally = b.kind == Ally;
            dl->AddCircleFilled(p, 7.0f, ally ? IM_COL32(74, 222, 128, 56) : IM_COL32(248, 113, 113, 56), 16);
            dl->AddCircleFilled(p, 3.5f, ally ? IM_COL32(74, 222, 128, 255) : IM_COL32(248, 113, 113, 255), 16);
        }
    }

    // Player marker and rim.
    dl->AddTriangleFilled(ImVec2(c.x, c.y - 8), ImVec2(c.x - 5, c.y + 5), ImVec2(c.x + 5, c.y + 5), IM_COL32(255, 255, 255, 255));
    dl->AddCircle(c, r, AccentU32(0.9f), 64, 1.5f);

    char range[24];
    std::snprintf(range, sizeof(range), "%.0f m", g.radar_range);
    dl->AddText(ImVec2(c.x - ImGui::CalcTextSize(range).x * 0.5f, c.y + r * 0.55f), AccentU32(0.9f), range);

    ImGui::Dummy(ImVec2(size, size));
}

// In-game HUD pieces drawn behind every window: crosshair, FPS counter, watermark.
void DrawOverlay() {
    ImDrawList* bg = ImGui::GetBackgroundDrawList();
    const ImGuiViewport* vp = ImGui::GetMainViewport();
    const float alpha = static_cast<float>(g.overlay_opacity) / 100.0f;
    const float s = g.hud_scale;

    if (g.show_crosshair) {
        const ImVec2 c = vp->GetCenter();
        const ImU32 col = ImGui::ColorConvertFloat4ToU32(ImVec4(g.crosshair_color[0], g.crosshair_color[1], g.crosshair_color[2], g.crosshair_color[3] * alpha));
        const float len = g.crosshair_size * s, gap = g.crosshair_gap * s;
        switch (g.crosshair_style) {
            case 1:
                bg->AddCircleFilled(c, 2.5f * s, col, 12);
                break;
            case 2:
                bg->AddCircle(c, len * 0.5f + gap, col, 32, 1.5f * s);
                break;
            default:
                if (g.crosshair_style != 3) bg->AddLine(ImVec2(c.x, c.y - gap), ImVec2(c.x, c.y - gap - len), col, 2.0f * s);
                bg->AddLine(ImVec2(c.x, c.y + gap), ImVec2(c.x, c.y + gap + len), col, 2.0f * s);
                bg->AddLine(ImVec2(c.x - gap, c.y), ImVec2(c.x - gap - len, c.y), col, 2.0f * s);
                bg->AddLine(ImVec2(c.x + gap, c.y), ImVec2(c.x + gap + len, c.y), col, 2.0f * s);
                break;
        }
    }

    char lines[2][48];
    int count = 0;
    if (g.show_watermark && g.watermark[0] != '\0') std::snprintf(lines[count++], sizeof(lines[0]), "%s", g.watermark);
    if (g.show_fps) std::snprintf(lines[count++], sizeof(lines[0]), "%.0f FPS", ImGui::GetIO().Framerate);

    const bool right = g.overlay_corner == 1 || g.overlay_corner == 3;
    const bool bottom = g.overlay_corner >= 2;
    const float pad = 16.0f * s, line_h = ImGui::GetTextLineHeight() + 4.0f;
    for (int i = 0; i < count; ++i) {
        const ImVec2 size = ImGui::CalcTextSize(lines[i]);
        const float x = right ? vp->Pos.x + vp->Size.x - pad - size.x : vp->Pos.x + pad;
        const float y = bottom ? vp->Pos.y + vp->Size.y - pad - line_h * static_cast<float>(count - i) : vp->Pos.y + pad + line_h * static_cast<float>(i);
        bg->AddRectFilled(ImVec2(x - 6, y - 2), ImVec2(x + size.x + 6, y + size.y + 2), IM_COL32(4, 4, 9, static_cast<int>(160 * alpha)), 4.0f);
        bg->AddText(ImVec2(x, y), i == 0 && g.show_watermark ? AccentU32(alpha) : IM_COL32(255, 255, 255, static_cast<int>(255 * alpha)), lines[i]);
    }
}

void VisualsTab() {
    ImGui::SeparatorText("HUD elements");
    ImGui::Checkbox("FPS counter", &g.show_fps);
    ImGui::Checkbox("Crosshair", &g.show_crosshair);
    ImGui::Checkbox("Minimap radar", &g.show_radar);

    ImGui::SeparatorText("Crosshair");
    ImGui::Combo("Style", &g.crosshair_style, kCrosshairStyles, IM_ARRAYSIZE(kCrosshairStyles));
    ImGui::SliderFloat("Crosshair size", &g.crosshair_size, 4.0f, 48.0f, "%.0f px");
    ImGui::SliderFloat("Crosshair gap", &g.crosshair_gap, 0.0f, 16.0f, "%.0f px");
    ImGui::ColorEdit4("Crosshair color", g.crosshair_color, ImGuiColorEditFlags_NoInputs | ImGuiColorEditFlags_AlphaBar);
}

void OverlayTab() {
    ImGui::SeparatorText("Overlay");
    ImGui::SliderInt("Overlay opacity", &g.overlay_opacity, 10, 100, "%d%%");
    ImGui::Combo("Position", &g.overlay_corner, kOverlayCorners, IM_ARRAYSIZE(kOverlayCorners));
    ImGui::SliderFloat("HUD scale", &g.hud_scale, 0.5f, 2.0f, "%.2fx");
    ImGui::Checkbox("Watermark", &g.show_watermark);
    ImGui::InputText("Watermark text", g.watermark, sizeof(g.watermark));

    ImGui::SeparatorText("Performance");
    float avg = 0.0f;
    for (float ms : g_frame_ms) avg += ms;
    avg /= static_cast<float>(IM_ARRAYSIZE(g_frame_ms));
    char overlay[32];
    std::snprintf(overlay, sizeof(overlay), "avg %.1f ms", avg);
    ImGui::TextDisabled("Frame time (ms)");
    ImGui::PlotLines("##frame_time", g_frame_ms, IM_ARRAYSIZE(g_frame_ms), g_frame_head, overlay, 0.0f, 33.3f, ImVec2(-1.0f, 72.0f));

    char budget[32];
    std::snprintf(budget, sizeof(budget), "%.1f / 16.7 ms", avg);
    ImGui::TextDisabled("Frame budget");
    ImGui::ProgressBar(avg / 16.7f, ImVec2(-1.0f, 0.0f), budget);
}

void RadarTab() {
    const float size = ImGui::GetContentRegionAvail().x < 220.0f ? ImGui::GetContentRegionAvail().x : 220.0f;
    if (g.show_radar) {
        DrawRadar(size);
    } else {
        ImGui::TextDisabled("Turn on Minimap radar in Visuals to preview it.");
    }
    ImGui::SliderFloat("Radar range", &g.radar_range, 50.0f, 500.0f, "%.0f m");
    ImGui::SliderFloat("Radar zoom", &g.radar_zoom, 0.5f, 3.0f, "%.1fx");
    ImGui::Checkbox("Rotate with player", &g.radar_rotate);
    ImGui::Checkbox("Show objectives", &g.radar_objectives);
}

void SettingsTab() {
    ImGui::SeparatorText("Theme");
    if (ImGui::Combo("Theme", &g.theme, kThemes, IM_ARRAYSIZE(kThemes))) ApplyColors();
    if (ImGui::ColorEdit4("Accent color", g.accent, ImGuiColorEditFlags_NoInputs | ImGuiColorEditFlags_NoAlpha)) ApplyColors();

    ImGui::SeparatorText("Controls");
    ImGui::InputText("Menu keybind", g.keybind, sizeof(g.keybind), ImGuiInputTextFlags_CharsUppercase);
    ImGui::Checkbox("Pause game while open", &g.pause_on_open);

    ImGui::SeparatorText("Config");
    ImGui::InputText("Config name", g.config_name, sizeof(g.config_name));
    if (ImGui::Button("Save config")) {
        // TODO: write MenuState to <config_name>.cfg with your own serializer.
        std::snprintf(g_status, sizeof(g_status), "Saved %s.cfg", g.config_name);
    }
    ImGui::SameLine();
    if (ImGui::Button("Reset")) {
        g = MenuState{};
        ApplyColors();
        std::snprintf(g_status, sizeof(g_status), "%s", "Defaults restored");
    }
    if (g_status[0] != '\0') {
        ImGui::TextColored(Accent(1.0f), "%s", g_status);
    } else {
        ImGui::TextDisabled("Changes apply live. Save to keep them.");
    }
}

}  // namespace

namespace ninetail {

void ApplyStyle() {
    ImGuiStyle& style = ImGui::GetStyle();
    style.WindowRounding = 12.0f;
    style.ChildRounding = 10.0f;
    style.FrameRounding = 7.0f;
    style.PopupRounding = 8.0f;
    style.GrabRounding = 7.0f;
    style.TabRounding = 7.0f;
    style.ScrollbarRounding = 8.0f;
    style.WindowPadding = ImVec2(16.0f, 14.0f);
    style.FramePadding = ImVec2(10.0f, 6.0f);
    style.ItemSpacing = ImVec2(10.0f, 8.0f);
    style.ItemInnerSpacing = ImVec2(8.0f, 6.0f);
    style.GrabMinSize = 12.0f;
    style.WindowBorderSize = 1.0f;
    style.FrameBorderSize = 0.0f;
    style.TabBorderSize = 0.0f;
    style.WindowTitleAlign = ImVec2(0.5f, 0.5f);
    style.SeparatorTextBorderSize = 1.0f;
    style.SeparatorTextPadding = ImVec2(12.0f, 4.0f);
    ApplyColors();
}

void RenderUI(bool* p_open) {
    // Record frame times for the Performance graph.
    static bool seeded = false;
    if (!seeded) {
        for (float& ms : g_frame_ms) ms = 16.7f;
        seeded = true;
    }
    g_frame_ms[g_frame_head] = ImGui::GetIO().DeltaTime * 1000.0f;
    g_frame_head = (g_frame_head + 1) % IM_ARRAYSIZE(g_frame_ms);

    DrawOverlay();  // The HUD stays on screen while the menu is closed.
    if (p_open != nullptr && !*p_open) return;
    // TODO: toggle *p_open when the key in g.keybind is pressed; pause the game if g.pause_on_open.

    ImGui::SetNextWindowSize(ImVec2(560.0f, 480.0f), ImGuiCond_FirstUseEver);
    if (ImGui::Begin("NineTail HUD Menu", p_open, ImGuiWindowFlags_NoCollapse)) {
        if (ImGui::BeginTabBar("##tabs")) {
            if (ImGui::BeginTabItem("Visuals")) {
                VisualsTab();
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("Overlay")) {
                OverlayTab();
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("Radar")) {
                RadarTab();
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("Settings")) {
                SettingsTab();
                ImGui::EndTabItem();
            }
            ImGui::EndTabBar();
        }
    }
    ImGui::End();
}

}  // namespace ninetail`;

const gui: GuiSpec = {
  title: "NineTail HUD Menu",
  width: 560,
  height: 480,
  accent: "#67e8f9",
  overlay: { fps: true, crosshair: true, watermark: "NINETAIL" },
  tabs: [
    {
      label: "Visuals",
      widgets: [
        { type: "separator", label: "HUD elements" },
        { type: "checkbox", label: "FPS counter", value: true },
        { type: "checkbox", label: "Crosshair", value: true },
        { type: "checkbox", label: "Minimap radar", value: true },
        { type: "separator", label: "Crosshair" },
        { type: "combo", label: "Style", options: ["Cross", "Dot", "Circle", "T-shape"], value: "Cross" },
        { type: "slider", label: "Crosshair size", value: 12, min: 4, max: 48, format: "%.0f px" },
        { type: "slider", label: "Crosshair gap", value: 4, min: 0, max: 16, format: "%.0f px" },
        { type: "color", label: "Crosshair color", value: "#67e8f9" },
      ],
    },
    {
      label: "Overlay",
      widgets: [
        { type: "separator", label: "Overlay" },
        { type: "slider", label: "Overlay opacity", value: 85, min: 10, max: 100, format: "%d%%" },
        { type: "combo", label: "Position", options: ["Top left", "Top right", "Bottom left", "Bottom right"], value: "Top right" },
        { type: "slider", label: "HUD scale", value: 1, min: 0.5, max: 2, format: "%.2fx" },
        { type: "checkbox", label: "Watermark", value: true },
        { type: "input", label: "Watermark text", value: "NINETAIL" },
        { type: "separator", label: "Performance" },
        {
          type: "plot",
          label: "Frame time (ms)",
          min: 0,
          max: 33.3,
          points: [11.8, 12.1, 11.4, 12.6, 11.9, 13.4, 12.2, 11.7, 11.5, 12.8, 14.1, 12.3, 11.6, 11.9, 12.4, 11.8, 11.2, 12.0, 12.7, 11.9, 11.4, 12.2, 13.0, 11.8],
        },
        { type: "progress", label: "Frame budget", value: 0.73 },
      ],
    },
    {
      label: "Radar",
      widgets: [
        {
          type: "radar",
          label: "Radar",
          value: "150 m",
          blips: [
            { x: 0.32, y: -0.46, kind: "ally" },
            { x: -0.38, y: -0.18, kind: "ally" },
            { x: 0.56, y: 0.28, kind: "enemy" },
            { x: -0.22, y: 0.6, kind: "enemy" },
            { x: 0.7, y: -0.12, kind: "enemy" },
            { x: -0.08, y: -0.78, kind: "objective" },
          ],
        },
        { type: "slider", label: "Radar range", value: 150, min: 50, max: 500, format: "%.0f m" },
        { type: "slider", label: "Radar zoom", value: 1, min: 0.5, max: 3, format: "%.1fx" },
        { type: "checkbox", label: "Rotate with player", value: true },
        { type: "checkbox", label: "Show objectives", value: true },
      ],
    },
    {
      label: "Settings",
      widgets: [
        { type: "separator", label: "Theme" },
        { type: "combo", label: "Theme", options: ["Spirit Night", "Obsidian", "Frost"], value: "Spirit Night" },
        { type: "color", label: "Accent color", value: "#67e8f9" },
        { type: "separator", label: "Controls" },
        { type: "input", label: "Menu keybind", value: "INSERT" },
        { type: "checkbox", label: "Pause game while open", value: false },
        { type: "separator", label: "Config" },
        { type: "input", label: "Config name", value: "default" },
        { type: "button", label: "Save config" },
        { type: "button", label: "Reset", sameLine: true },
        { type: "text", label: "Changes apply live. Save to keep them." },
      ],
    },
  ],
};

export const imguiModMenuDemo: DemoParts = {
  title: "NineTail HUD Menu",
  language: "cpp",
  code,
  gui,
};

import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}", "./lib/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Deep obsidian surfaces, darkest first.
        obsidian: {
          950: "#040409",
          900: "#07070d",
          850: "#0a0a12",
          800: "#0e0e18",
          700: "#151522",
          600: "#1d1d2d",
          500: "#2a2a3f",
        },
        // Spirit-fire accents.
        spirit: {
          violet: "#a78bfa",
          "violet-deep": "#7c3aed",
          "violet-soft": "#c4b5fd",
          cyan: "#67e8f9",
          "cyan-deep": "#22d3ee",
          pink: "#f0abfc",
        },
        fox: {
          white: "#f6f4ff",
          mist: "#d9d4f5",
          muted: "#9a96b8",
          dim: "#6b6889",
        },
      },
      fontFamily: {
        sans: ["var(--font-sora)", "ui-sans-serif", "system-ui", "sans-serif"],
        mono: ["var(--font-mono)", "ui-monospace", "SFMono-Regular", "monospace"],
      },
      boxShadow: {
        "glow-violet": "0 0 0 1px rgba(167,139,250,.35), 0 0 24px rgba(139,92,246,.35), 0 0 64px rgba(124,58,237,.18)",
        "glow-cyan": "0 0 0 1px rgba(103,232,249,.35), 0 0 24px rgba(34,211,238,.30)",
        "glow-white": "0 0 0 1px rgba(255,255,255,.25), 0 0 28px rgba(246,244,255,.25)",
        glass: "inset 0 1px 0 rgba(255,255,255,.06), 0 24px 60px -20px rgba(0,0,0,.7)",
      },
      backgroundImage: {
        "spirit-fire": "linear-gradient(120deg, #f6f4ff 0%, #c4b5fd 35%, #a78bfa 60%, #67e8f9 100%)",
        "ignite": "linear-gradient(110deg, #7c3aed 0%, #a78bfa 45%, #67e8f9 100%)",
      },
      keyframes: {
        "spirit-pan": {
          "0%": { backgroundPosition: "0% 50%" },
          "100%": { backgroundPosition: "200% 50%" },
        },
        "soft-pulse": {
          "0%, 100%": { opacity: "0.55" },
          "50%": { opacity: "1" },
        },
      },
      animation: {
        "spirit-pan": "spirit-pan 6s linear infinite",
        "soft-pulse": "soft-pulse 2.4s ease-in-out infinite",
      },
    },
  },
  plugins: [],
};

export default config;

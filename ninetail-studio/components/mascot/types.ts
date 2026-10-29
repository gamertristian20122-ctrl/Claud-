import type { MascotState } from "@/lib/types";

export interface KitsuneMascotProps {
  /** idle: tails sway. thinking: tails flare and pulse in sequence. done: celebratory aura flash. */
  state: MascotState;
  /** Rendered width and height in px. Defaults to 160. */
  size?: number;
  className?: string;
}

import type { Metadata, Viewport } from "next";
import { JetBrains_Mono, Sora } from "next/font/google";
import "./globals.css";

const sora = Sora({ subsets: ["latin"], variable: "--font-sora", display: "swap" });
const mono = JetBrains_Mono({ subsets: ["latin"], variable: "--font-mono", display: "swap" });

export const metadata: Metadata = {
  title: "NineTail Studio",
  description:
    "Describe it, ignite it. NineTail Studio turns a prompt into a web page, a Dear ImGui desktop menu or a CustomTkinter app, with a live preview.",
};

export const viewport: Viewport = {
  themeColor: "#040409",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${sora.variable} ${mono.variable}`}>
      <body className="font-sans">{children}</body>
    </html>
  );
}

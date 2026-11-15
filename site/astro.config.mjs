// @ts-check
import { defineConfig } from "astro/config";
import react from "@astrojs/react";
import tailwindcss from "@tailwindcss/vite";

// GitHub Pages：https://kajisho5.github.io/genba-tokei/
export default defineConfig({
  site: "https://kajisho5.github.io",
  base: "/genba-tokei",
  integrations: [react()],
  vite: { plugins: [tailwindcss()] },
});

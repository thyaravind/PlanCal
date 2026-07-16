import { resolve } from "node:path";
import { defineConfig } from "vite";
import { viteSingleFile } from "vite-plugin-singlefile";

const classicDOMContentLoadedScript = {
  name: "plancal-classic-dom-content-loaded-script",
  enforce: "post" as const,
  generateBundle(
    _options: unknown,
    bundle: Record<string, { type: string; fileName: string; source?: string | Uint8Array }>
  ): void {
    for (const output of Object.values(bundle)) {
      if (output.type !== "asset" || !output.fileName.endsWith(".html") || typeof output.source !== "string") {
        continue;
      }
      output.source = output.source
        .replace(
          /<script type="module" crossorigin>/,
          '<script>window.addEventListener("DOMContentLoaded",()=>{'
        )
        .replace("</script>", "});</script>");
    }
  }
};

export default defineConfig({
  plugins: [viteSingleFile(), classicDOMContentLoadedScript],
  build: {
    assetsInlineLimit: 100_000_000,
    cssCodeSplit: false,
    emptyOutDir: false,
    outDir: "../Plancal/Resources",
    rollupOptions: {
      input: resolve(process.cwd(), "MarkdownEditor.html"),
      output: {
        inlineDynamicImports: true
      }
    }
  }
});

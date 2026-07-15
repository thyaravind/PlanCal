import { resolve } from "node:path";
import { defineConfig } from "vite";
import { viteSingleFile } from "vite-plugin-singlefile";

export default defineConfig({
  plugins: [viteSingleFile()],
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

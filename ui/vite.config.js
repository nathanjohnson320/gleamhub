import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'
import gleam from "vite-gleam";

export default defineConfig({
  appType: "spa",
  plugins: [gleam(), tailwindcss()],
  server: {
    proxy: {
      "/api": {
        target: "http://localhost:9999",
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: "../server/priv/static",
    emptyOutDir: true,
  },
});

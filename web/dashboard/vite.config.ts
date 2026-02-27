import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

// Default: mukuro = 6960 (むくろ)
const MUKURO_API = process.env.MUKURO_API_URL ?? 'http://localhost:6960';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 3960,
    strictPort: false,
    open: true,
    proxy: {
      '/api': {
        target: MUKURO_API,
        changeOrigin: true,
      },
      '/ws': {
        target: MUKURO_API,
        ws: true,
      },
    },
  },
  preview: {
    port: 3960,
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    sourcemap: true,
  },
});

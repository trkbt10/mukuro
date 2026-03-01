import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

const MUKURO_API = process.env.MUKURO_API_URL ?? 'http://localhost:6960';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      'react-editor-ui/viewers/MarkdownViewer/parser': path.resolve(
        __dirname,
        'node_modules/react-editor-ui/src/viewers/MarkdownViewer/parser',
      ),
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
      '/health': {
        target: MUKURO_API,
        changeOrigin: true,
      },
      '/status': {
        target: MUKURO_API,
        changeOrigin: true,
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

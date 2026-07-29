import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({
  plugins: [react()],
  build: {
    ssr: 'ssr/yearend-preview.tsx', outDir: 'ssr-out', emptyOutDir: false, target: 'node22',
    rollupOptions: { external: ['react','react-dom','react-dom/server','node:fs'] },
  },
});

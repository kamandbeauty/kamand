import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    ssr: 'ssr/render.tsx',
    outDir: 'ssr-out',
    emptyOutDir: true,
    target: 'node22',
    rollupOptions: { external: ['react', 'react-dom', 'react-dom/server'] },
  },
});

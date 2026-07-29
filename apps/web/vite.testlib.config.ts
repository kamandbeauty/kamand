import { defineConfig } from 'vite';

/** ساخت ماژول‌های خالص برای آزمون در Node */
export default defineConfig({
  build: {
    outDir: 'test-out',
    emptyOutDir: true,
    target: 'node22',
    ssr: true,
    rollupOptions: {
      input: {
        storage: 'src/storage.ts',
        barcode: 'src/barcode.ts',
        syncEngine: 'src/syncEngine.ts',
        workspaces: 'src/workspaces.ts',
      },
      output: { entryFileNames: '[name].js' },
    },
  },
});

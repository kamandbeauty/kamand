import { defineConfig } from 'vite';

/** ساخت ماژول ذخیره‌سازی برای آزمون در Node */
export default defineConfig({
  build: {
    ssr: 'src/storage.ts',
    outDir: 'test-out',
    emptyOutDir: true,
    target: 'node22',
  },
});

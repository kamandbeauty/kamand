import { startServer } from './http.js';

const port = Number(process.env.PORT ?? 8787);
const { server } = startServer(port);

server.on('listening', () => {
  console.log(`جاوید — سرور همگام‌سازی روی پورت ${port}`);
  console.log(`پایگاه داده: ${process.env.JAVID_DB ?? 'حافظه (موقت)'}`);
});

for (const sig of ['SIGINT', 'SIGTERM'] as const) {
  process.on(sig, () => {
    console.log('\nخاموش شدن…');
    server.close(() => process.exit(0));
  });
}

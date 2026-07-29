import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './styles.css';
import { registerServiceWorker } from './pwa';

const el = document.getElementById('root');
if (el) createRoot(el).render(<React.StrictMode><App /></React.StrictMode>);

// نصب سرویس‌ورکر — شکست آن نباید برنامه را متوقف کند
registerServiceWorker();

import plugin from 'tailwindcss/plugin';

/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        midnight: {
          950: '#05070f',
          900: '#0b1026',
          800: '#111737',
          700: '#1a2350',
          600: '#232e63',
        },
        gold: {
          200: '#f6e7c1',
          300: '#eed9a6',
          400: '#e8c77b',
          500: '#d9b264',
          600: '#c9a24b',
        },
      },
      fontFamily: {
        vazir: ['Vazirmatn', 'Tahoma', 'sans-serif'],
      },
      boxShadow: {
        glow: '0 0 24px -6px rgba(232,199,123,0.35)',
        'glow-sm': '0 0 14px -4px rgba(232,199,123,0.45)',
      },
    },
  },
  plugins: [
    plugin(({ addVariant }) => addVariant('light', ':where(.light) &')),
  ],
}

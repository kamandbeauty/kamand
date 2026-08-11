/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        blue: {
          50: '#FFF7ED',
          100: '#FFEDD5',
          200: '#FED7AA',
          300: '#FDBA74',
          400: '#FB923C',
          500: '#F97316',
          600: '#F97316',
          700: '#EA580C',
          800: '#9A3412',
          900: '#7C2D12',
          950: '#431407',
        },
        primary: {
          50: '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
          950: '#172554',
        },
        ruby: {
          blue: '#1976D2',
          lightBlue: '#E3F2FD',
          darkBlue: '#0D47A1',
          bgLight: '#F8FAFC',
          cardLight: '#FFFFFF',
        }
      },
      borderRadius: {
        '2xl': '1rem',
        '3xl': '1.5rem',
        '4xl': '2rem',
      },
      fontFamily: {
        vazir: ['Vazirmatn', 'B Yekan', 'Tahoma', 'sans-serif'],
      }
    },
  },
  plugins: [],
}

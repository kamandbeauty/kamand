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
          50: '#EFF7FD',
          100: '#DCEFFB',
          200: '#B9DFF7',
          300: '#93CEF1',
          400: '#5FB4E9',
          500: '#3FA2E4',
          600: '#2D92DF',
          700: '#1E78C0',
          800: '#1A5F99',
          900: '#174B77',
          950: '#0F3354',
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

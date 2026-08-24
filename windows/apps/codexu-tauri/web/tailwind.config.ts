/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        accent: {
          DEFAULT: 'var(--accent)',
          secondary: 'var(--accent-secondary)',
        },
        surface: {
          DEFAULT: 'var(--surface)',
          elevated: 'var(--surface-elevated)',
          inset: 'var(--surface-inset)',
        },
        status: {
          ok: 'var(--status-ok)',
          warn: 'var(--status-warn)',
          error: 'var(--status-error)',
        },
        data: {
          primary: 'var(--data-primary)',
          secondary: 'var(--data-secondary)',
          tertiary: 'var(--data-tertiary)',
        },
      },
      fontFamily: {
        sans: ['SF Pro Text', 'Inter', 'Segoe UI', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
};

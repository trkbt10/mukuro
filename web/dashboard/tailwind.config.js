/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // OpenAI-style color palette
        primary: {
          DEFAULT: '#10a37f',
          hover: '#0d8c6d',
          light: '#1a7f64',
        },
        surface: {
          DEFAULT: '#ffffff',
          secondary: '#f7f7f8',
          tertiary: '#ececf1',
        },
        text: {
          DEFAULT: '#202123',
          secondary: '#6e6e80',
          muted: '#8e8ea0',
        },
        border: {
          DEFAULT: '#e5e5e5',
          light: '#f0f0f0',
        },
        // Dark mode colors
        dark: {
          surface: {
            DEFAULT: '#343541',
            secondary: '#444654',
            tertiary: '#40414f',
          },
          text: {
            DEFAULT: '#ececf1',
            secondary: '#c5c5d2',
            muted: '#8e8ea0',
          },
          border: {
            DEFAULT: '#565869',
          },
        },
      },
      fontFamily: {
        sans: [
          'Söhne',
          'ui-sans-serif',
          'system-ui',
          '-apple-system',
          'Segoe UI',
          'Roboto',
          'Helvetica Neue',
          'Arial',
          'sans-serif',
        ],
        mono: ['Söhne Mono', 'Monaco', 'Andale Mono', 'Ubuntu Mono', 'monospace'],
      },
      fontSize: {
        xs: ['0.75rem', { lineHeight: '1rem' }],
        sm: ['0.875rem', { lineHeight: '1.25rem' }],
        base: ['1rem', { lineHeight: '1.5rem' }],
        lg: ['1.125rem', { lineHeight: '1.75rem' }],
        xl: ['1.25rem', { lineHeight: '1.75rem' }],
        '2xl': ['1.5rem', { lineHeight: '2rem' }],
      },
      borderRadius: {
        DEFAULT: '0.375rem',
        sm: '0.25rem',
        md: '0.5rem',
        lg: '0.75rem',
        xl: '1rem',
      },
      boxShadow: {
        card: '0 1px 3px rgba(0, 0, 0, 0.08)',
        dropdown: '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
        modal: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
      },
      animation: {
        'spin-slow': 'spin 2s linear infinite',
        'fade-in': 'fadeIn 0.2s ease-out',
        'slide-up': 'slideUp 0.2s ease-out',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(10px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
      },
    },
  },
  plugins: [],
};

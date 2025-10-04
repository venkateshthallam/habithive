import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        honey: {
          50: '#fef9ee',
          100: '#fdf3d7',
          200: '#fae5ae',
          300: '#f7d179',
          400: '#f4b942',
          500: '#f1a220',
          600: '#e28413',
          700: '#bb6512',
          800: '#954f16',
          900: '#794215',
        },
        hive: {
          50: '#fef7ee',
          100: '#fdecd7',
          200: '#fad6ae',
          300: '#f6b97a',
          400: '#f19244',
          500: '#ed741f',
          600: '#de5a15',
          700: '#b84314',
          800: '#923618',
          900: '#762f16',
        },
      },
      animation: {
        'float': 'float 3s ease-in-out infinite',
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-20px)' },
        },
      },
    },
  },
  plugins: [],
};

export default config;

import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        ink: "#080910",
        panel: "#111321",
        violet: "#8B5CF6",
        electric: "#38BDF8"
      },
      boxShadow: {
        glow: "0 0 40px rgba(139,92,246,.16)"
      }
    }
  },
  plugins: []
};
export default config;

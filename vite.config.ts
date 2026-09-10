import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// spike 最小壳：仅验证 Tauri + Vite 在 windows-latest 出包链路
export default defineConfig({
  plugins: [react()],
  clearScreen: false,
  server: {
    port: 5173,
    strictPort: true,
  },
  build: {
    target: 'es2022',
  },
})

import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  base: '/woodcraft/adminportal/',
  plugins: [react()],
})

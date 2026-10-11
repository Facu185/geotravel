import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // En Windows, con el repo dentro de OneDrive, el vigilante de archivos de Vite a veces se
    // pierde cambios y el navegador queda con código viejo. El sondeo lo evita (cuesta poca CPU).
    watch: { usePolling: true, interval: 300 },
  },
});

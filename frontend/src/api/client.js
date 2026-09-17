const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8080/geotravel/api";

/**
 * Wrapper mínimo de fetch. Cada módulo lo usa así:
 *   const zonas = await api.get("/zonas");
 * Reemplazar/ampliar con manejo de errores propio del equipo si hace falta.
 */
async function request(path, options = {}) {
  const res = await fetch(`${API_URL}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!res.ok) {
    throw new Error(`${options.method ?? "GET"} ${path} -> ${res.status}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

export const api = {
  get: (path) => request(path),
  post: (path, body) => request(path, { method: "POST", body: body ? JSON.stringify(body) : undefined }),
  put: (path, body) => request(path, { method: "PUT", body: body ? JSON.stringify(body) : undefined }),
  del: (path) => request(path, { method: "DELETE" }),
};

const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8080/geotravel/api";

/**
 * Wrapper mínimo de fetch. Cada módulo lo usa así:
 *   const zonas = await api.get("/zonas");
 *
 * Si el backend responde con error (400 datos inválidos, 409 solapamiento, ...)
 * el mensaje de la excepción es el texto que mandó el backend ({"error": "..."}),
 * listo para mostrarle al usuario.
 */
async function leerRespuesta(res, descripcion) {
  if (!res.ok) {
    const body = await res.json().catch(() => null);
    throw new Error(body?.error ?? `${descripcion} -> ${res.status}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

async function request(path, options = {}) {
  const res = await fetch(`${API_URL}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  return leerRespuesta(res, `${options.method ?? "GET"} ${path}`);
}

/**
 * Sube un archivo (multipart/form-data) en el campo "archivo".
 * No se fija Content-Type a mano: lo agrega el navegador, con el "boundary" que hace falta.
 */
async function upload(path, archivo) {
  const datos = new FormData();
  datos.append("archivo", archivo);
  const res = await fetch(`${API_URL}${path}`, { method: "POST", body: datos });
  return leerRespuesta(res, `POST ${path}`);
}

export const api = {
  get: (path) => request(path),
  post: (path, body) => request(path, { method: "POST", body: body ? JSON.stringify(body) : undefined }),
  put: (path, body) => request(path, { method: "PUT", body: body ? JSON.stringify(body) : undefined }),
  del: (path) => request(path, { method: "DELETE" }),
  upload,
};

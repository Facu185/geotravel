import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "./AuthContext.jsx";

/**
 * Agrupa las rutas que solo ve el administrador. Sin sesión, manda al ingreso y, al ingresar,
 * vuelve a la pantalla que se quería abrir.
 */
export default function RutaAdmin() {
  const { esAdmin, cargando } = useAuth();
  const ubicacion = useLocation();

  if (cargando) return <p className="aviso aviso--info" role="status">Comprobando la sesión…</p>;
  if (!esAdmin) return <Navigate to="/login" replace state={{ desde: ubicacion.pathname }} />;
  return <Outlet />;
}

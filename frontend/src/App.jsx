import { NavLink, Route, Routes, Navigate, useLocation, useNavigate } from "react-router-dom";
import ZonasPage from "./modules/zonas/ZonasPage.jsx";
import RecursosPage from "./modules/recursos/RecursosPage.jsx";
import IncidentesPage from "./modules/incidentes/IncidentesPage.jsx";
import ConsultasPage from "./modules/consultas/ConsultasPage.jsx";
import InvitadoPage from "./modules/invitado/InvitadoPage.jsx";
import LoginPage from "./auth/LoginPage.jsx";
import RutaAdmin from "./auth/RutaAdmin.jsx";
import { AuthProvider, useAuth } from "./auth/AuthContext.jsx";

// "admin": solo se muestra (y se puede abrir) con sesión de administrador. El mapa público es para todos.
const NAV = [
  { to: "/invitado", label: "Mapa público", module: "P5" },
  { to: "/zonas", label: "Zonas operativas", module: "P3", admin: true },
  { to: "/recursos", label: "Recursos", module: "P3", admin: true },
  { to: "/incidentes", label: "Incidentes", module: "P4", admin: true },
  { to: "/consultas", label: "Consultas", module: "P5", admin: true },
];

const RUTAS_CON_MAPA = ["/invitado", "/zonas", "/recursos", "/incidentes", "/consultas"];

/** Marca: un "ping" de radar, con el punto en el rojo de máxima prioridad. */
function LogoMarca() {
  return (
    <svg className="marca__logo" viewBox="0 0 32 32" width="30" height="30" aria-hidden="true" focusable="false">
      <circle cx="16" cy="16" r="13" fill="none" stroke="currentColor" strokeWidth="2" opacity=".35" />
      <circle cx="16" cy="16" r="8" fill="none" stroke="currentColor" strokeWidth="2" opacity=".7" />
      <circle cx="16" cy="16" r="3.6" fill="#ef5b45" />
    </svg>
  );
}

function Aplicacion() {
  // Las páginas con mapa lo muestran a pantalla completa (con un panel flotante); las que no
  // tienen mapa van en una columna centrada.
  const { pathname } = useLocation();
  const esMapa = RUTAS_CON_MAPA.some((ruta) => pathname.startsWith(ruta));
  const { esAdmin, sesion, salir } = useAuth();
  const navegar = useNavigate();

  const alSalir = async () => {
    await salir();
    navegar("/invitado");
  };

  return (
    <div className={esMapa ? "app app--mapa" : "app"}>
      <header className="cabecera">
        <div className="cabecera__barra">
          <h1 className="marca">
            <NavLink to="/invitado">
              <LogoMarca />
              <span className="marca__nombre">UrbanSafe</span>
              <span className="marca__lema">Emergencias urbanas</span>
            </NavLink>
          </h1>
          <nav className="navegacion" aria-label="Secciones">
            {NAV.filter((item) => !item.admin || esAdmin).map((item) => (
              <NavLink key={item.to} to={item.to}>
                {item.label}
              </NavLink>
            ))}
          </nav>
          <div className="cabecera__sesion">
            {esAdmin ? (
              <>
                <span className="cabecera__usuario">{sesion.usuario}</span>
                <button type="button" className="cabecera__salir" onClick={alSalir}>
                  Salir
                </button>
              </>
            ) : (
              <NavLink to="/login" className="cabecera__ingresar">
                Ingresar
              </NavLink>
            )}
          </div>
        </div>
        {/* Los 5 colores de prioridad de las zonas operativas (ver geoserver/styles). */}
        <div className="franja" aria-hidden="true" />
      </header>

      <main className={esMapa ? "contenido contenido--mapa" : "contenido"}>
        <Routes>
          <Route path="/" element={<Navigate to="/invitado" replace />} />
          <Route path="/invitado" element={<InvitadoPage />} />
          <Route path="/login" element={<LoginPage />} />
          <Route element={<RutaAdmin />}>
            <Route path="/zonas" element={<ZonasPage />} />
            <Route path="/recursos" element={<RecursosPage />} />
            <Route path="/incidentes" element={<IncidentesPage />} />
            <Route path="/consultas" element={<ConsultasPage />} />
          </Route>
        </Routes>
      </main>
    </div>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <Aplicacion />
    </AuthProvider>
  );
}

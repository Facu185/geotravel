import { useEffect, useRef, useState } from "react";
import { NavLink, Route, Routes, Navigate, useLocation, useNavigate } from "react-router-dom";
import ZonasPage from "./modules/zonas/ZonasPage.jsx";
import RecursosPage from "./modules/recursos/RecursosPage.jsx";
import IncidentesPage from "./modules/incidentes/IncidentesPage.jsx";
import ConsultasPage from "./modules/consultas/ConsultasPage.jsx";
import InvitadoPage from "./modules/invitado/InvitadoPage.jsx";
import EtaPage from "./modules/eta/EtaPage.jsx";
import LoginPage from "./auth/LoginPage.jsx";
import RutaAdmin from "./auth/RutaAdmin.jsx";
import { AuthProvider, useAuth } from "./auth/AuthContext.jsx";

// "admin": solo se muestra (y se puede abrir) con sesión de administrador. El mapa público es para todos.
const NAV = [
  { to: "/invitado", label: "Mapa público", module: "P5" },
  { to: "/zonas", label: "Zonas operativas", module: "P3", admin: true },
  { to: "/recursos", label: "Recursos", module: "P3", admin: true },
  { to: "/incidentes", label: "Incidentes", module: "P4", admin: true },
  { to: "/consultas", label: "Consultas", module: "P5" },
  { to: "/eta", label: "Tiempo de llegada", module: "P2", admin: true },
];

const RUTAS_CON_MAPA = ["/invitado", "/zonas", "/recursos", "/incidentes", "/consultas", "/eta"];

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

  // En pantallas angostas las secciones y la sesión van en un menú hamburguesa (ver "menú hamburguesa" en styles.css).
  const [menuAbierto, setMenuAbierto] = useState(false);
  const cabeceraRef = useRef(null);

  // El menú se cierra al cambiar de pantalla (también con "atrás"), con Escape y al tocar fuera de la cabecera.
  useEffect(() => {
    setMenuAbierto(false);
  }, [pathname]);

  useEffect(() => {
    if (!menuAbierto) return undefined;
    const alTocarFuera = (e) => {
      if (cabeceraRef.current && !cabeceraRef.current.contains(e.target)) setMenuAbierto(false);
    };
    const alTeclear = (e) => {
      if (e.key === "Escape") setMenuAbierto(false);
    };
    document.addEventListener("pointerdown", alTocarFuera);
    document.addEventListener("keydown", alTeclear);
    return () => {
      document.removeEventListener("pointerdown", alTocarFuera);
      document.removeEventListener("keydown", alTeclear);
    };
  }, [menuAbierto]);

  const alSalir = async () => {
    await salir();
    navegar("/invitado");
  };

  return (
    <div className={esMapa ? "app app--mapa" : "app"}>
      <header className="cabecera" ref={cabeceraRef}>
        <div className="cabecera__barra">
          <h1 className="marca">
            <NavLink to="/invitado">
              <LogoMarca />
              <span className="marca__nombre">UrbanSafe</span>
              <span className="marca__lema">Emergencias urbanas</span>
            </NavLink>
          </h1>
          <button
            type="button"
            className="cabecera__menu"
            aria-label={menuAbierto ? "Cerrar el menú" : "Abrir el menú"}
            aria-expanded={menuAbierto}
            aria-controls="menu-principal"
            onClick={() => setMenuAbierto((abierto) => !abierto)}
          >
            <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true" focusable="false">
              <path
                d={menuAbierto ? "M6 6l12 12M18 6L6 18" : "M4 7h16M4 12h16M4 17h16"}
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
              />
            </svg>
          </button>
          {/* Con espacio, el contenido se acomoda en la barra; en pantallas angostas es el menú desplegable. Un toque en un enlace o botón lo cierra. */}
          <div
            id="menu-principal"
            className={menuAbierto ? "cabecera__contenido cabecera__contenido--abierto" : "cabecera__contenido"}
            onClick={(e) => e.target.closest("a, button") && setMenuAbierto(false)}
          >
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
        </div>
        {/* Los 5 colores de prioridad de las zonas operativas (ver geoserver/styles). */}
        <div className="franja" aria-hidden="true" />
      </header>

      <main className={esMapa ? "contenido contenido--mapa" : "contenido"}>
        <Routes>
          <Route path="/" element={<Navigate to="/invitado" replace />} />
          <Route path="/invitado" element={<InvitadoPage />} />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/consultas" element={<ConsultasPage />} />
          <Route element={<RutaAdmin />}>
            <Route path="/zonas" element={<ZonasPage />} />
            <Route path="/recursos" element={<RecursosPage />} />
            <Route path="/incidentes" element={<IncidentesPage />} />
            <Route path="/eta" element={<EtaPage />} />
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

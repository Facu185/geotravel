import { NavLink, Route, Routes, Navigate } from "react-router-dom";
import ZonasPage from "./modules/zonas/ZonasPage.jsx";
import AtraccionesPage from "./modules/atracciones/AtraccionesPage.jsx";
import RecorridosPage from "./modules/recorridos/RecorridosPage.jsx";
import ConsultasPage from "./modules/consultas/ConsultasPage.jsx";
import InvitadoPage from "./modules/invitado/InvitadoPage.jsx";

const NAV = [
  { to: "/invitado", label: "Mapa público", module: "P5" },
  { to: "/zonas", label: "Zonas", module: "P3" },
  { to: "/atracciones", label: "Atracciones", module: "P3" },
  { to: "/recorridos", label: "Recorridos", module: "P4" },
  { to: "/consultas", label: "Consultas", module: "P5" },
];

export default function App() {
  return (
    <div style={{ fontFamily: "system-ui, sans-serif", maxWidth: 960, margin: "0 auto", padding: 16 }}>
      <h1>GeoTravel</h1>
      <nav style={{ display: "flex", gap: 12, marginBottom: 16, flexWrap: "wrap" }}>
        {NAV.map((item) => (
          <NavLink key={item.to} to={item.to} style={({ isActive }) => ({ fontWeight: isActive ? "bold" : "normal" })}>
            {item.label}
          </NavLink>
        ))}
      </nav>

      <Routes>
        <Route path="/" element={<Navigate to="/invitado" replace />} />
        <Route path="/invitado" element={<InvitadoPage />} />
        <Route path="/zonas" element={<ZonasPage />} />
        <Route path="/atracciones" element={<AtraccionesPage />} />
        <Route path="/recorridos" element={<RecorridosPage />} />
        <Route path="/consultas" element={<ConsultasPage />} />
      </Routes>
    </div>
  );
}

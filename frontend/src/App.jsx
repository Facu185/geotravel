import { NavLink, Route, Routes, Navigate } from "react-router-dom";
import ZonasPage from "./modules/zonas/ZonasPage.jsx";
import RecursosPage from "./modules/recursos/RecursosPage.jsx";
import IncidentesPage from "./modules/incidentes/IncidentesPage.jsx";
import ConsultasPage from "./modules/consultas/ConsultasPage.jsx";
import InvitadoPage from "./modules/invitado/InvitadoPage.jsx";

const NAV = [
  { to: "/invitado", label: "Mapa público", module: "P5" },
  { to: "/zonas", label: "Zonas operativas", module: "P3" },
  { to: "/recursos", label: "Recursos", module: "P3" },
  { to: "/incidentes", label: "Incidentes", module: "P4" },
  { to: "/consultas", label: "Consultas", module: "P5" },
];

export default function App() {
  return (
    <div style={{ fontFamily: "system-ui, sans-serif", maxWidth: 960, margin: "0 auto", padding: 16 }}>
      <h1>UrbanSafe</h1>
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
        <Route path="/recursos" element={<RecursosPage />} />
        <Route path="/incidentes" element={<IncidentesPage />} />
        <Route path="/consultas" element={<ConsultasPage />} />
      </Routes>
    </div>
  );
}

import { useState } from "react";
import { Link, Navigate, useLocation, useNavigate } from "react-router-dom";
import { Aviso } from "../components/ui.jsx";
import { useAuth } from "./AuthContext.jsx";

/** Ingreso del administrador. El invitado no necesita ingresar: ve el mapa público. */
export default function LoginPage() {
  const { esAdmin, ingresar } = useAuth();
  const navegar = useNavigate();
  const ubicacion = useLocation();
  const destino = ubicacion.state?.desde ?? "/zonas";

  const [usuario, setUsuario] = useState("");
  const [clave, setClave] = useState("");
  const [error, setError] = useState(null);
  const [enviando, setEnviando] = useState(false);

  if (esAdmin) return <Navigate to={destino} replace />;

  const enviar = async (evento) => {
    evento.preventDefault();
    setError(null);
    setEnviando(true);
    try {
      await ingresar(usuario.trim(), clave);
      navegar(destino, { replace: true });
    } catch (e) {
      setError(e.message);
      setEnviando(false);
    }
  };

  return (
    <section className="ingreso" aria-labelledby="titulo-ingreso">
      <h2 id="titulo-ingreso" className="ingreso__titulo">
        Ingreso de administración
      </h2>
      <p className="ayuda">Para administrar zonas, recursos e incidentes y hacer consultas. El mapa público no necesita ingresar.</p>
      <form className="ingreso__formulario" onSubmit={enviar}>
        <label className="campo" htmlFor="ingreso-usuario">
          <span className="campo__etiqueta">Usuario</span>
          <input id="ingreso-usuario" value={usuario} onChange={(e) => setUsuario(e.target.value)} autoComplete="username" required />
        </label>
        <label className="campo" htmlFor="ingreso-clave">
          <span className="campo__etiqueta">Contraseña</span>
          <input id="ingreso-clave" type="password" value={clave} onChange={(e) => setClave(e.target.value)} autoComplete="current-password" required />
        </label>
        {error && <Aviso tipo="error">{error}</Aviso>}
        <button type="submit" className="btn btn--primario btn--ancho" disabled={enviando || !usuario.trim() || !clave}>
          {enviando ? "Ingresando…" : "Ingresar"}
        </button>
      </form>
      <p className="ayuda">
        <Link to="/invitado">Volver al mapa público</Link>
      </p>
    </section>
  );
}

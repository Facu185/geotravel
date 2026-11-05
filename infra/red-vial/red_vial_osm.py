#!/usr/bin/env python3
"""
Convierte un extracto de OpenStreetMap (.osm.pbf) en los arcos de la red vial para pgRouting.

    python red_vial_osm.py uruguay.osm.pbf red_vial.csv.gz

Qué hace:
  1. Se queda con las vías por donde puede pasar un auto (autopistas, rutas, avenidas, calles y calles de servicio,
     con sus enlaces) y descarta las privadas, las peatonales, las sendas y los caminos rurales sin pavimento (track).
  2. Parte cada vía en las ESQUINAS: un nodo de OpenStreetMap que comparten dos o más vías (o el extremo de una vía) es un
     vértice del grafo, y cada arco va de un vértice al siguiente. Dos vías que se cruzan sin compartir nodo (un puente,
     un túnel) NO se conectan, como en la realidad.
  3. Conserva lo que hace falta para rutear de verdad: nombre, número de ruta, tipo, SENTIDO (doble mano, mano única o
     mano única al revés), VELOCIDAD máxima, rotondas, puentes y túneles.

La salida es un CSV (una fila por arco) que carga infra/red-vial/cargar.sh y arma el grafo con db/sql/red_vial_generar.sql.
Con un tercer argumento escribe además los LUGARES del extracto (ciudades, pueblos, barrios: nodos con la etiqueta `place`),
que sirven para decir "cerca de X" cuando un cruce de calles existe en varios lugares del país.
Con un cuarto argumento escribe además las CALLES de todo el país (la capa de referencia `via`: toda vía con nombre, también
las peatonales y los caminos, una fila por vía entera), con el tipo que usa el estilo vias_tipo.sld.
Cubre todo lo que traiga el extracto, no solo Salto. © colaboradores de OpenStreetMap, licencia ODbL.
"""
import csv
import gzip
import re
import sys

import numpy as np
import osmium

# highway -> se rutea. Los *_link son los enlaces (ramas de salida y entrada).
TIPOS = {
    "motorway", "motorway_link", "trunk", "trunk_link", "primary", "primary_link", "secondary", "secondary_link",
    "tertiary", "tertiary_link", "unclassified", "residential", "living_street", "service",
}
SERVICIOS_EXCLUIDOS = {"parking_aisle", "driveway", "drive-through", "emergency_access"}
ACCESO_NO = {"no", "private"}


def velocidad(valor):
    """'40', '40 km/h', '25 mph' -> km/h entero; None si no se entiende (o es 'signals', 'none', etc.)."""
    if not valor:
        return None
    m = re.match(r"^\s*(\d+(?:\.\d+)?)\s*(mph|km/h|kmh)?\s*$", valor.strip().lower())
    if not m:
        return None
    v = float(m.group(1))
    if m.group(2) == "mph":
        v *= 1.609
    return int(round(v)) if 5 <= v <= 140 else None


def sentido(tags, highway):
    """'doble', 'directo' (mano única en el sentido del trazado) o 'inverso' (mano única al revés)."""
    oneway = (tags.get("oneway") or "").lower()
    if oneway in ("-1", "reverse"):
        return "inverso"
    if oneway in ("yes", "true", "1"):
        return "directo"
    if oneway in ("no", "false", "0"):
        return "doble"
    # Sin etiqueta: las autopistas y las rotondas son de mano única por definición.
    if highway in ("motorway", "motorway_link") or tags.get("junction") in ("roundabout", "circular"):
        return "directo"
    return "doble"


def transitable(tags):
    highway = tags.get("highway")
    if highway not in TIPOS:
        return False
    if tags.get("area") == "yes":
        return False
    if tags.get("access") in ACCESO_NO or tags.get("motor_vehicle") in ACCESO_NO or tags.get("vehicle") in ACCESO_NO:
        return False
    if highway == "service" and tags.get("service") in SERVICIOS_EXCLUIDOS:
        return False
    return True


class CuentaNodos(osmium.SimpleHandler):
    """Pasada 1: cuántas veces aparece cada nodo en las vías transitables (para saber cuáles son esquinas)."""

    def __init__(self):
        super().__init__()
        self.refs = []

    def way(self, w):
        if transitable(w.tags):
            self.refs.append(np.fromiter((n.ref for n in w.nodes), dtype=np.int64))


LUGARES = {"city", "town", "village", "hamlet", "suburb", "neighbourhood"}


class Lugares(osmium.SimpleHandler):
    """Los nodos con nombre que son ciudades, pueblos, barrios... (para ubicar un cruce de calles)."""

    def __init__(self, salida):
        super().__init__()
        self.salida = salida
        self.cantidad = 0

    def node(self, n):
        lugar = n.tags.get("place")
        nombre = n.tags.get("name")
        if lugar in LUGARES and nombre and n.location.valid():
            poblacion = re.sub(r"\D", "", n.tags.get("population", ""))
            self.salida.writerow([nombre, lugar, poblacion, f"{n.lon:.6f}", f"{n.lat:.6f}"])
            self.cantidad += 1


# highway de OpenStreetMap -> tipo de la capa via (los valores que reconoce geoserver/styles/vias_tipo.sld)
TIPO_VIA = {
    "motorway": "RUTA NACIONAL", "motorway_link": "RUTA NACIONAL", "trunk": "RUTA NACIONAL", "trunk_link": "RUTA NACIONAL",
    "primary": "AVENIDA", "primary_link": "AVENIDA", "secondary": "AVENIDA", "secondary_link": "AVENIDA",
    "tertiary": "CALLE", "tertiary_link": "CALLE", "residential": "CALLE", "unclassified": "CALLE", "living_street": "CALLE",
    "service": "CALLE", "road": "CALLE",
    "track": "CAMINO",
    "footway": "PEATONAL", "path": "PEATONAL", "pedestrian": "PEATONAL", "steps": "PEATONAL", "cycleway": "PEATONAL",
    "bridleway": "PEATONAL",
    "proposed": "PROYECTADA", "construction": "PROYECTADA",
}


class Vias(osmium.SimpleHandler):
    """Toda vía con nombre (una fila por vía entera, no partida en esquinas) para la capa de referencia `via`."""

    def __init__(self, salida):
        super().__init__()
        self.salida = salida
        self.cantidad = 0

    def way(self, w):
        tipo = TIPO_VIA.get(w.tags.get("highway"))
        nombre = w.tags.get("name")
        if tipo is None or not nombre or w.tags.get("area") == "yes":
            return
        puntos = [(n.lon, n.lat) for n in w.nodes if n.location.valid()]
        if len(puntos) < 2:
            return
        wkt = "LINESTRING(" + ",".join(f"{lon:.6f} {lat:.6f}" for lon, lat in puntos) + ")"
        self.salida.writerow([nombre.upper()[:60], tipo, wkt])
        self.cantidad += 1


class Arcos(osmium.SimpleHandler):
    """Pasada 2: parte cada vía en las esquinas y escribe un arco por tramo."""

    def __init__(self, esquinas, salida):
        super().__init__()
        self.esquinas = esquinas  # array ordenado de ids de nodo que son esquinas
        self.salida = salida
        self.arcos = 0

    def es_esquina(self, ref):
        i = np.searchsorted(self.esquinas, ref)
        return i < len(self.esquinas) and self.esquinas[i] == ref

    def way(self, w):
        if not transitable(w.tags):
            return
        t = w.tags
        highway = t["highway"]
        puntos = []
        for n in w.nodes:
            if n.location.valid():
                puntos.append((n.ref, n.lon, n.lat))
        if len(puntos) < 2:
            return
        tramo = [puntos[0]]
        for p in puntos[1:]:
            tramo.append(p)
            if self.es_esquina(p[0]) or p is puntos[-1]:
                self.escribir(w, highway, tramo)
                tramo = [p]

    def escribir(self, w, highway, tramo):
        if len(tramo) < 2 or tramo[0][0] == tramo[-1][0] and len(tramo) < 3:
            return
        t = w.tags
        wkt = "LINESTRING(" + ",".join(f"{lon:.6f} {lat:.6f}" for _, lon, lat in tramo) + ")"
        self.salida.writerow([
            w.id, tramo[0][0], tramo[-1][0], t.get("name", ""), t.get("ref", ""), highway, sentido(t, highway),
            velocidad(t.get("maxspeed")) or "",
            "t" if t.get("junction") in ("roundabout", "circular") else "f",
            "t" if t.get("bridge") not in (None, "", "no") else "f",
            "t" if t.get("tunnel") not in (None, "", "no") else "f",
            wkt,
        ])
        self.arcos += 1


def main(pbf, destino, destino_lugares=None, destino_vias=None):
    print(f"Pasada 1: contando nodos de {pbf} ...", flush=True)
    cuenta = CuentaNodos()
    cuenta.apply_file(pbf)
    todos = np.concatenate(cuenta.refs)
    ids, veces = np.unique(todos, return_counts=True)
    # Esquina: nodo que está en 2 o más vías, o repetido dentro de una misma vía (un lazo).
    esquinas = ids[veces >= 2]
    print(f"  {len(cuenta.refs)} vías, {len(esquinas)} esquinas", flush=True)
    # Los extremos de cada vía también son vértices (se agregan cuando llegan al último punto).
    del todos, ids, veces, cuenta

    print("Pasada 2: partiendo las vías en tramos ...", flush=True)
    with gzip.open(destino, "wt", encoding="utf-8", newline="") as f:
        salida = csv.writer(f)
        salida.writerow(["osm_way_id", "origen", "destino", "nombre", "referencia", "highway", "sentido",
                         "velocidad_kmh", "rotonda", "puente", "tunel", "wkt"])
        arcos = Arcos(esquinas, salida)
        arcos.apply_file(pbf, locations=True, idx="flex_mem")
    print(f"  {arcos.arcos} arcos escritos en {destino}", flush=True)

    if destino_lugares:
        with gzip.open(destino_lugares, "wt", encoding="utf-8", newline="") as f:
            salida = csv.writer(f)
            salida.writerow(["nombre", "tipo", "poblacion", "lon", "lat"])
            lugares = Lugares(salida)
            lugares.apply_file(pbf)
        print(f"  {lugares.cantidad} lugares escritos en {destino_lugares}", flush=True)

    if destino_vias:
        with gzip.open(destino_vias, "wt", encoding="utf-8", newline="") as f:
            salida = csv.writer(f)
            salida.writerow(["nom_calle", "tipo", "wkt"])
            vias = Vias(salida)
            vias.apply_file(pbf, locations=True, idx="flex_mem")
        print(f"  {vias.cantidad} vías con nombre escritas en {destino_vias}", flush=True)


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4, 5):
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) >= 4 else None, sys.argv[4] if len(sys.argv) == 5 else None)

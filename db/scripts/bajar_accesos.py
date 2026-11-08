"""Uso: python db/scripts/bajar_accesos.py  (necesita internet; tarda unos 15 minutos).

Baja las puertas (imm:mdg_accesos) y los nombres de sus tramos de calle (geomatica:v_mdg_vias_montevideo)
del WFS de la Intendencia de Montevideo y arma db/data/accesos.csv.gz:
num_puerta, letra, nom_calle, cod_nombre, x, y (EPSG:32721).

El servicio no tiene clave primaria en estas capas (no admite paginar) y cuelga algunos pedidos al azar:
se baja por ventanas del gid del tramo, con timeout corto y reintentos; si una ventana no sale,
se parte en dos. Se escribe a un archivo temporal y recién al terminar se renombra."""
import csv
import gzip
import json
import os
import time
import urllib.parse
import urllib.request

B = "https://geoserver.montevideo.gub.uy/geoserver/ows"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "accesos.csv.gz")
VENTANA = 100000
MAXIMO = 25000000


def pedir(tipo, extra, intentos=8):
    q = {"service": "WFS", "version": "2.0.0", "request": "GetFeature", "typeNames": tipo,
         "outputFormat": "application/json", "srsName": "EPSG:32721"}
    q.update(extra)
    url = B + "?" + urllib.parse.urlencode(q)
    for n in range(intentos):
        try:
            return json.load(urllib.request.urlopen(url, timeout=12))
        except Exception as e:
            print("  reintento", n + 1, type(e).__name__, flush=True)
            time.sleep(1)
    return None


def accesos_ventana(ini, fin):
    """Puertas con gid_tramo_via en [ini, fin]; parte la ventana en dos si el pedido no sale."""
    r = pedir("imm:mdg_accesos",
              {"propertyName": "num_puerta,letra,gid_tramo_via,visible,the_geom",
               "cql_filter": "visible=true AND gid_tramo_via BETWEEN %d AND %d" % (ini, fin)})
    if r is not None:
        return r["features"]
    if fin - ini < 1000:
        raise SystemExit("no se pudo bajar la ventana %d-%d" % (ini, fin))
    medio = (ini + fin) // 2
    return accesos_ventana(ini, medio) + accesos_ventana(medio + 1, fin)


def tramos_lote(gids):
    r = pedir("geomatica:v_mdg_vias_montevideo",
              {"propertyName": "gid,nom_calle,cod_nombre_via",
               "cql_filter": "gid IN (%s)" % ",".join(map(str, gids))})
    if r is not None:
        return r["features"]
    if len(gids) == 1:
        raise SystemExit("no se pudo bajar el tramo %s" % gids[0])
    m = len(gids) // 2
    return tramos_lote(gids[:m]) + tramos_lote(gids[m:])


# 1. puertas: ventanas finas donde están casi todos los gid y ventanas grandes para los pocos gid altos
puertas = []
tramos_ventanas = [(i, i + VENTANA - 1) for i in range(0, MAXIMO, VENTANA)]
tramos_ventanas += [(i, i + 25000000 - 1) for i in range(MAXIMO, 400000000, 25000000)]
for ini, fin in tramos_ventanas:
    fs = accesos_ventana(ini, fin)
    puertas.extend(fs)
    if fs:
        print("puertas", len(puertas), "hasta gid", fin, flush=True)

# 2. nombre de cada tramo
gids = sorted({f["properties"]["gid_tramo_via"] for f in puertas})
print("tramos distintos:", len(gids), flush=True)
tramos = {}
from concurrent.futures import ThreadPoolExecutor
lotes = [gids[i:i + 100] for i in range(0, len(gids), 100)]
with ThreadPoolExecutor(max_workers=8) as pool:
    for n, fs in enumerate(pool.map(tramos_lote, lotes)):
        for f in fs:
            p = f["properties"]
            tramos[p["gid"]] = (p["nom_calle"], p["cod_nombre_via"])
        if n % 20 == 0:
            print("tramos resueltos", len(tramos), "de", len(gids), flush=True)

# 3. archivo (temporal, y se renombra al terminar)
tmp = OUT + ".tmp"
filas = 0
sin_tramo = 0
vistos = set()
with gzip.open(tmp, "wt", encoding="utf-8", newline="") as gz:
    w = csv.writer(gz)
    w.writerow(["num_puerta", "letra", "nom_calle", "cod_nombre", "x", "y"])
    for f in puertas:
        p = f["properties"]
        t = tramos.get(p["gid_tramo_via"])
        if not t:
            sin_tramo += 1
            continue
        x, y = f["geometry"]["coordinates"]
        letra = (p["letra"] or "").strip()
        clave = (t[0], p["num_puerta"], letra, round(x, 1), round(y, 1))
        if clave in vistos:
            continue
        vistos.add(clave)
        w.writerow([p["num_puerta"], letra, t[0], t[1], round(x, 2), round(y, 2)])
        filas += 1
os.replace(tmp, OUT)
print("LISTO", filas, "filas;", sin_tramo, "puertas sin tramo", flush=True)


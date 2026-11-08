# Modelo entidad-relación (MER)

Sale de las migraciones de `db/migrations` (V1 a V4). Las geometrías están en SRID 32721 (UTM 21 Sur, metros).

```mermaid
erDiagram
    ZONA_OPERATIVA {
        int id PK
        text nombre "obligatorio"
        text descripcion
        smallint nivel_prioridad "1 a 5, 1 = máxima"
        text responsable
        text observaciones
        polygon geom "puede superponerse con otras zonas"
    }

    RECURSO {
        int id PK
        text identificacion "ej. Ambulancia 12"
        text nombre
        text tipo "ambulancia, bomberos, patrulla, centro_atencion, otro"
        text estado_operativo "Disponible, En servicio, Fuera de servicio"
        text descripcion
        point geom
    }

    INCIDENTE {
        int id PK
        text titulo "obligatorio"
        text descripcion
        text tipo_incidente "accidente_transito, incendio, corte_servicio, inundacion, otro"
        smallint prioridad "1 a 5"
        text estado "Registrado, En atención, Derivado, Resuelto, Cancelado"
        timestamp fecha_hora_registro
        text equipo_responsable
        geometry geom "punto, línea o polígono"
    }

    INCIDENTE_RECURSO {
        int incidente_id PK, FK
        int recurso_id PK, FK
        timestamp fecha_asignacion
    }

    HISTORIAL_ESTADO {
        int id PK
        int incidente_id FK
        text estado
        timestamp fecha_hora
        text usuario "quién hizo el cambio"
    }

    VIA {
        int gid PK
        text nom_calle
        text tipo
        linestring geom "tramo de calle"
    }

    ACCESO {
        int id PK
        int num_puerta
        text letra
        text nom_calle
        int cod_nombre
        point geom "número de puerta"
    }

    RED_VIAL_VERTICE {
        bigint id PK "nodo de OpenStreetMap (una esquina)"
        point geom "esquina"
    }

    RED_VIAL_ARCO {
        bigint id PK
        bigint source FK "esquina de salida"
        bigint target FK "esquina de llegada"
        linestring geom "tramo de esquina a esquina"
        text nombre
        text highway "tipo de vía"
        int velocidad_kmh
        boolean mano_unica
        float cost_m "metros (reverse_cost_m < 0: sentido prohibido)"
        float cost_s "segundos (reverse_cost_s < 0: sentido prohibido)"
    }

    LUGAR_OSM {
        int id PK
        text nombre "ciudad, pueblo o barrio"
        text tipo
        point geom
    }

    INCIDENTE ||--o{ INCIDENTE_RECURSO : "tiene asignados"
    RECURSO ||--o{ INCIDENTE_RECURSO : "atiende"
    INCIDENTE ||--o{ HISTORIAL_ESTADO : "registra cambios de estado"
    ZONA_OPERATIVA }o..o{ INCIDENTE : "contiene (relación espacial)"
    ZONA_OPERATIVA |o..o{ RECURSO : "contiene (relación espacial)"
    VIA ||..o{ ACCESO : "misma calle (por nombre)"
    RED_VIAL_VERTICE ||--o{ RED_VIAL_ARCO : "esquina de salida (source) y de llegada (target)"
```

## Cómo leerlo

- **Líneas continuas:** relaciones con clave foránea real.
  - Un incidente tiene muchos cambios de estado (`historial_estado`). Si se borra el incidente, se borra su historial.
  - `incidente_recurso` es la tabla intermedia de una relación N a M: un incidente puede tener varios recursos asignados y un recurso puede haber atendido varios incidentes. Guarda la fecha de asignación.
- **Líneas punteadas:** relaciones **espaciales**, que no tienen clave foránea. Se calculan con PostGIS al consultar.
  - Una zona contiene incidentes (`ST_Intersects`) y recursos (`ST_Contains`). Un incidente puede cruzar varias zonas o ninguna. Un recurso puede estar en más de una zona, porque las zonas pueden superponerse.
  - Las puertas se relacionan con las calles por el nombre y no por una clave.
- `VIA` y `ACCESO` son capas de referencia (calles y números de puerta de Salto). No se editan desde la aplicación.
- `RED_VIAL_VERTICE` y `RED_VIAL_ARCO` son la red por la que pgRouting calcula las rutas (OpenStreetMap de todo Uruguay, con sentidos y velocidades). La arma el servicio `red-vial`; tampoco se editan desde la aplicación. `LUGAR_OSM` son las ciudades, pueblos y barrios del mismo extracto, para decir en qué lugar queda un cruce de calles. Ver `docs/RED_VIAL.md`.

## Reglas y automatismos de la base

| Qué | Dónde | Detalle |
|---|---|---|
| Prioridad entre 1 y 5 | `zona_operativa`, `incidente` | `CHECK` |
| Estados válidos | `incidente.estado` | `CHECK` con los cinco estados de la letra |
| Estado operativo válido | `recurso.estado_operativo` | `CHECK` con tres valores |
| Primer registro del historial | `trg_incidente_historial_inicial` | Al crear un incidente, un trigger inserta su estado inicial en `historial_estado` |
| Zonas válidas | Backend (`ZonaResource`) | `ST_IsValid` y que sea un polígono (las zonas pueden superponerse; el trigger de V1 que lo impedía está comentado) |
| Búsqueda espacial rápida | Índices GiST en cada `geom` | Para cercanía y pertenencia a zonas |
| Puertas y calles | `idx_acceso_*`, `idx_via_*` | Búsqueda por nombre con trigramas |

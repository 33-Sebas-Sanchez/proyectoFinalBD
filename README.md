# Proyecto Final de Bases de Datos

Sistema de inventario, compras y ventas en PostgreSQL: modelo de datos,
arquitectura distribuida por microservicios, fragmentación horizontal por sede,
diccionario de datos, matriz de roles RBAC, vistas consolidadas, 20 consultas
analíticas y backend Spring Boot.

## Estructura

```
LaTeX/          Fuentes editables (.tex y .sty)
Documentos/     PDF finales listos para entregar
Scripts sql/    Scripts PostgreSQL por microservicio (tablas, constraints, datos, seguridad, FDW, vistas y consultas)
Backend/        Seis microservicios Spring Boot (una base de datos por servicio)
render.yaml     Blueprint de Render para desplegar los microservicios
Makefile        Compila y publica todos los PDF en Documentos/
```

### Fuentes (`LaTeX/`) y documentos finales (`Documentos/`)

| PDF (`Documentos/`)                              | Fuente (`LaTeX/`)         | Contenido                                                       |
| ------------------------------------------------ | ------------------------- | --------------------------------------------------------------- |
| `Planteamiento_y_diseno_BD.pdf`                  | `planteamiento.tex`       | Planteamiento, alcance, supuestos, reglas, 3FN y fragmentación  |
| `Diagramas/Diagrama_ER_proyecto_final_BD.pdf`    | `diagrama_er.tex`         | Diagrama entidad-relación (TikZ, notación de Chen)              |
| `Diagramas/Diagrama_de_microservicios_BD.pdf`    | `microservicios.tex`      | Arquitectura de microservicios (TikZ)                           |
| `Diccionario_de_datos_BD.pdf`                    | `diccionario.tex`         | Diccionario de datos actualizado con particiones LIST           |
| `Matrices/Matriz_roles_BD.pdf`                   | `roles.tex`               | Matriz de roles y permisos (RBAC)                               |
| `Matrices/Modificacion_de_datos_BD.pdf`          | `dimensiones.tex`         | Propuesta delimitada de dimensiones                             |
| `Resultados_y_pruebas_BD.pdf`                    | `resultados_pruebas.tex`  | Evidencias de las 20 consultas, 10 pruebas y conclusiones       |
| `Manual_de_instalacion_BD.pdf`                   | `manual_instalacion.tex`  | Manual paso a paso (local, psql/pgAdmin, Neon y Spring Boot)    |

### Scripts SQL (`Scripts sql/`)

- `catalogo_terceros/`, `compras_abastecimiento/`, `inventarios_transferencias/`, `ventas_pagos/`, `identidad_accesos/`:
  cada carpeta contiene `01_tablas.sql` (con particionamiento `PARTITION BY LIST (id_sede)` en `inventarios` y `pedidos_venta`), `02_constraints.sql`, `03_datos.sql` y `04_seguridad.sql`.
- `reportes/`: contiene `01_fdw_integracion.sql` (`postgres_fdw` solo lectura), `02_vistas.sql` (10 vistas obligatorias + 2 vistas `UNION ALL` de fragmentos = 12 vistas), `03_consultas_analiticas.sql` (20 consultas numeradas), `04_seguridad.sql`, `ejecutar_pruebas.sh` y `evidencias/`.
- `local-db.sh`: gestiona una instancia PostgreSQL local en `.pgdata/` (puerto `5433`).

## Ejecución rápida en local

```bash
# 1. Inicializar las 6 bases PostgreSQL locales y cargar todos los scripts
cd "Scripts sql"
./local-db.sh init
./local-db.sh pruebas     # Ejecuta las 10 pruebas de verificación
./local-db.sh consultas   # Ejecuta las 20 consultas analíticas

# 2. (Opcional) Levantar los 6 microservicios Spring Boot contra el clúster local
cd ../Backend
./run-all.sh start --build
./run-all.sh status
```

## Compilar documentación LaTeX

```bash
make          # compila todo y actualiza Documentos/
make limpio   # elimina temporales
```

Requiere XeLaTeX y las tipografías **STIX Two Text**, **STIX Two Math**,
**Source Sans 3** y **JetBrains Mono**.

## Integrantes

- Sergio Leonardo Moreno Granado
- Sebastián Camilo Sánchez Cárdenas

# Proyecto Final de Bases de Datos

Sistema de inventario, compras y ventas en PostgreSQL: modelo de datos,
microservicios por esquema, diccionario de datos, matriz de roles y
propuesta de dimensiones.

## Estructura

```
LaTeX/          Fuentes editables (.tex y .sty)
Documentos/     PDF finales listos para entregar
Scripts sql/    Scripts PostgreSQL de esquemas, tablas, restricciones y carga
Makefile        Compila y publica los PDF
```

### Fuentes (`LaTeX/`)

| Archivo                  | Contenido                                                |
| ------------------------ | -------------------------------------------------------- |
| `planteamiento.tex`      | Planteamiento, alcance, supuestos, reglas, 3FN y reparto |
| `diagrama_er.tex`        | Diagrama entidad-relación (TikZ, notación de Chen)       |
| `microservicios.tex`     | Arquitectura de microservicios por esquema (TikZ)        |
| `diccionario.tex`        | Diccionario de datos                                     |
| `roles.tex`              | Matriz de roles y permisos (RBAC)                        |
| `dimensiones.tex`        | Propuesta delimitada de dimensiones                      |
| `estilo-proyecto.sty`    | Estilo compartido: tipografías, secciones, tablas        |

### Documentos finales (`Documentos/`)

| PDF                                                       | Origen                |
| --------------------------------------------------------- | --------------------- |
| `Planteamiento_y_diseno_BD.pdf`                           | `planteamiento.tex`   |
| `Diagramas/Diagrama_ER_proyecto_final_BD.pdf`              | `diagrama_er.tex`     |
| `Diagramas/Diagrama_de_microservicios_BD.pdf`             | `microservicios.tex`  |
| `Diccionario_de_datos_BD.pdf`                             | `diccionario.tex`     |
| `Matrices/Matriz_roles_BD.pdf`                            | `roles.tex`           |
| `Matrices/Modificacion_de_datos_BD.pdf`                   | `dimensiones.tex`     |

## Compilar

```bash
make          # compila todo y actualiza Documentos/
make limpio  # elimina temporales
```

También se puede compilar un documento suelto:

```bash
texcompile LaTeX/diccionario.tex
```

Requiere XeLaTeX y las tipografías **STIX Two Text**, **STIX Two Math**,
**Source Sans 3** y **JetBrains Mono**.

## Integrantes

- Sergio Leonardo Moreno Granado
- Sebastián Sánchez

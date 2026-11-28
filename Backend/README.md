# Backend — microservicios

Seis microservicios Spring Boot, uno por dominio. Cada uno tiene **su propia
base de datos PostgreSQL en Neon** y no accede a las tablas de los demás.

## Servicios

| Servicio              | Puerto local | Base de datos (Neon)          | Prefijo en `.env` |
| --------------------- | ------------ | ----------------------------- | ----------------- |
| `catalogo-service`    | 8081         | catálogo y terceros           | `CATALOGO`        |
| `compras-service`     | 8082         | compras y abastecimiento      | `COMPRAS`         |
| `inventarios-service` | 8083         | inventarios y transferencias  | `INVENTARIOS`     |
| `ventas-service`      | 8084         | ventas y pagos                | `VENTAS`          |
| `identidad-service`   | 8085         | identidad y accesos           | `IDENTIDAD`       |
| `reportes-service`    | 8086         | reportes corporativos         | `REPORTES`        |

`reportes-service` no escribe en las bases de los demás ni mantiene tablas
propias: consulta las **12 vistas SQL** integradas mediante `postgres_fdw`
(`fuente: "postgres_vista"`, conectándose con el usuario de solo lectura
`usr_reportes_app`) y usa composición HTTP (`/api/resumen` o respaldo cuando
no hay vistas). Asimismo, `compras-service`, `inventarios-service` y
`ventas-service` validan las referencias lógicas inter-servicio (`idSede`,
`idAlmacen`, `idCliente`, `idEmpleado`, `idProveedor`, `idProducto`) mediante
HTTP contra `catalogo-service` e `identidad-service` antes de persistir.

## Requisitos

- **JDK 25** (Temurin). En este equipo está en
  `~/.local/opt/jdk-25.0.5.1+2`.
- Maven Wrapper incluido (`./mvnw`), no hace falta instalar Maven.

## Ejecutar en local

```bash
cd Backend
cp .env.example .env      # completa las 6 cadenas JDBC de Neon
./run-local.sh catalogo-service
```

El script carga `.env` y arranca el módulo con Maven. Para otro servicio,
cambia el argumento (`compras-service`, `ventas-service`, etc.).

Para levantar o detener **los 6 servicios juntos sin Docker**:

```bash
./run-all.sh start          # empaqueta si hace falta y arranca 8081..8086
./run-all.sh start --build  # recompila los JAR antes de arrancar
./run-all.sh status
./run-all.sh stop
```

Compilar todo sin arrancar:

```bash
./mvnw -q -B -DskipTests package
```

## Endpoints comunes

Todos los servicios exponen:

| Método | Ruta                          | Descripción                                   |
| ------ | ----------------------------- | --------------------------------------------- |
| `GET`  | `/api/health`                 | Estado del proceso y de su base de datos      |
| `GET`  | `/api/tablas`                 | Tablas y vistas del esquema `public`          |
| `GET`  | `/api/tablas/{tabla}`         | Primeras filas (`?limite=50`, máximo 200)     |
| `GET`  | `/api/resumen`                | Conteo de filas por tabla                     |
| `GET`  | `/api/reportes/resumen`       | Solo en `reportes-service`: consolidado       |

## Endpoints de negocio

- **`catalogo-service` (`8081`):** `GET /api/sedes`, `GET /api/almacenes`, `GET /api/categorias`, `GET|POST /api/productos`, `GET|PUT /api/productos/{id}`, `GET /api/proveedores`, `GET /api/productos/{id}/proveedores`, `GET|POST /api/clientes`.
- **`compras-service` (`8082`):** `GET|POST /api/ordenes-compra`, `GET /api/ordenes-compra/{id}`, `POST /api/recepciones`.
- **`inventarios-service` (`8083`):** `GET /api/inventarios` (`?idSede=&idAlmacen=&soloAlertas=true`), `GET /api/inventarios/por-sede`, `PATCH /api/inventarios/{idAlmacen}/{idProducto}`, `GET|POST /api/transferencias`, `GET /api/transferencias/{id}`.
- **`ventas-service` (`8084`):** `GET|POST /api/pedidos` (`?idSede=&estado=&idCliente=`), `GET /api/pedidos/{id}`, `GET|POST /api/pagos`, `GET /api/devoluciones`.
- **`identidad-service` (`8085`):** `GET /api/empleados`, `GET /api/usuarios` (sin `password_hash`), `GET /api/auditoria`, `POST /api/auth/login`.
- **`reportes-service` (`8086`):** `GET /api/reportes/resumen`, `GET /api/reportes/vistas`, `GET /api/reportes/vistas/{vista}`, `GET /api/reportes/corporativo`, `GET /api/reportes/alertas`, `GET /api/reportes/saldos-pendientes`.

Ejemplo:

```bash
curl http://localhost:8081/api/health
curl http://localhost:8081/api/tablas
curl "http://localhost:8081/api/tablas/productos?limite=10"
```

Los controladores descubren las tablas en `information_schema`, así que no se
rompen cuando el equipo cambia los scripts SQL.

## Abrir en IntelliJ IDEA

1. `File > Open` y selecciona `Backend/pom.xml`; ábrelo **como proyecto**.
2. En `File > Project Structure > SDKs > Add JDK`, elige
   `/home/leo/.local/opt/jdk-25.0.5.1+2`. Asígnalo como SDK del proyecto y usa
   *Language level* 25.
3. En `Settings > Build, Execution, Deployment > Build Tools > Maven > Runner`,
   pon el JRE en **25** (si no, Maven compila con el JDK que trae IntelliJ).
4. IntelliJ importa los seis módulos Maven automáticamente.
5. Para ejecutar un servicio, abre su clase `*Application` y pulsa Run, o
   crea una configuración **Spring Boot** con la clase principal.
6. En la configuración de ejecución agrega las variables `DB_URL`, `DB_USER`
   y `DB_PASSWORD` del servicio (o ejecuta `./run-local.sh` desde la terminal).

IntelliJ Community no incluye todos los asistentes de Spring de Ultimate,
pero compila, ejecuta y depura el proyecto sin problema.

## Desplegar en Render

El archivo `render.yaml` de la raíz define los seis servicios web con
`plan: free`.

1. Sube el backend a la rama principal del repositorio.
2. En Render: `New > Blueprint` y conecta el repositorio.
3. Render pedirá `DB_URL`, `DB_USER` y `DB_PASSWORD` de cada servicio.
   Pega los datos de la base correspondiente en Neon.
4. Las URLs de `reportes-service` se enlazan solas con `fromService`.

Cada servicio queda en `https://<nombre>.onrender.com`. El plan free duerme
los servicios tras 15 minutos sin tráfico; la primera petición tarda en
responder.

### Límites del plan free

- Render regala **750 horas de instancia al mes** por workspace. Los seis
  servicios comparten ese cupo.
- Un servicio free se duerme tras 15 minutos sin tráfico y **no consume horas**
  mientras está dormido. Al despertar tarda alrededor de un minuto.
- Si se agotan las 750 horas, Render suspende todos los servicios free hasta
  el mes siguiente. Para una demo o sustentación no debería ser problema.

## Arquitectura de datos

- **Una base por microservicio**, no un esquema compartido.
- No hay claves foráneas entre servicios: `id_producto`, `id_cliente`,
  `id_empleado`, etc. son referencias lógicas que `ValidadorReferencias`
  verifica por HTTP contra `catalogo-service` e `identidad-service` en cada
  operación `POST` (devolviendo `400 Bad Request` si algún ID no existe o si
  el almacén no corresponde a la sede).
- Dentro de cada base sí se conservan las claves foráneas internas.
- `reportes-service` lee las vistas SQL de solo lectura (`postgres_fdw`,
  usuario `usr_reportes_app`) y compone `/api/reportes/resumen` por HTTP, sin
  permisos de escritura cruzada.
- En `inventarios-service` y `ventas-service`, `/api/tablas` y `/api/resumen`
  descubren tanto la tabla particionada padre (`inventarios`, `pedidos_venta`)
  como sus cinco particiones físicas por sede (`*_sede_1`..`5`).

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

`reportes-service` no consulta las bases de los demás: compone la respuesta
llamando a `GET /api/resumen` de cada servicio. Es el patrón correcto cuando
cada microservicio es dueño de su base.

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
  `id_empleado`, etc. son identificadores que la API valida contra el servicio
  dueño.
- Dentro de cada base sí se conservan las claves foráneas internas.
- `reportes-service` consolida por HTTP, sin acceso cruzado a las bases.

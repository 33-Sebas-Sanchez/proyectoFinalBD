-- ============================================================================
-- MICROSERVICIO: reportes
-- 01. Integración inter-bases mediante postgres_fdw y esquemas locales
-- Motor: PostgreSQL 18 / Neon
-- ----------------------------------------------------------------------------
-- Importa en modo lectura las tablas (y particiones por sede) de las cinco
-- bases operacionales hacia esquemas homónimos dentro de la base `reportes`.
-- Nota: en despliegue Neon, reemplaza host/port/credenciales en cada SERVER
--       (agregando sslmode 'require') y omite password_required 'false' en
--       USER MAPPING, o utiliza el script automatizado ../neon-db.sh.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

CREATE SCHEMA IF NOT EXISTS catalogo_terceros;
CREATE SCHEMA IF NOT EXISTS compras_abastecimiento;
CREATE SCHEMA IF NOT EXISTS inventarios_transferencias;
CREATE SCHEMA IF NOT EXISTS ventas_pagos;
CREATE SCHEMA IF NOT EXISTS identidad_accesos;
CREATE SCHEMA IF NOT EXISTS reportes;

DO $$
DECLARE
    puerto TEXT := current_setting('port');
BEGIN
    -- Servidores externos (apuntan al mismo clúster local o instancias Neon)
    EXECUTE 'DROP SERVER IF EXISTS srv_catalogo CASCADE';
    EXECUTE format(
        'CREATE SERVER srv_catalogo FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host %L, port %L, dbname %L)',
        'localhost', puerto, 'catalogo_terceros'
    );

    EXECUTE 'DROP SERVER IF EXISTS srv_compras CASCADE';
    EXECUTE format(
        'CREATE SERVER srv_compras FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host %L, port %L, dbname %L)',
        'localhost', puerto, 'compras_abastecimiento'
    );

    EXECUTE 'DROP SERVER IF EXISTS srv_inventarios CASCADE';
    EXECUTE format(
        'CREATE SERVER srv_inventarios FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host %L, port %L, dbname %L)',
        'localhost', puerto, 'inventarios_transferencias'
    );

    EXECUTE 'DROP SERVER IF EXISTS srv_ventas CASCADE';
    EXECUTE format(
        'CREATE SERVER srv_ventas FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host %L, port %L, dbname %L)',
        'localhost', puerto, 'ventas_pagos'
    );

    EXECUTE 'DROP SERVER IF EXISTS srv_identidad CASCADE';
    EXECUTE format(
        'CREATE SERVER srv_identidad FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host %L, port %L, dbname %L)',
        'localhost', puerto, 'identidad_accesos'
    );
END $$;

-- Mapeo único de solo lectura (PUBLIC incluye a postgres, usr_reportes_admin,
-- usr_reportes_gerencia, usr_reportes_auditor, usr_reportes_lector y usr_reportes_app).
-- Al usar exclusivamente los usuarios lectores/auditores remotos, PostgreSQL impide
-- cualquier escritura (INSERT/UPDATE/DELETE) desde `reportes` hacia los demás servicios.
-- En despliegue Neon (auth scram-sha-256 y rol neondb_owner sin superusuario),
-- debe omitirse password_required 'false' y agregar sslmode 'require' al SERVER.
CREATE USER MAPPING FOR PUBLIC SERVER srv_catalogo
    OPTIONS (user 'usr_catalogo_lector', password 'Catalogo#Lector_2026', password_required 'false');
CREATE USER MAPPING FOR PUBLIC SERVER srv_compras
    OPTIONS (user 'usr_compras_auditor', password 'Compras#Audi_2026', password_required 'false');
CREATE USER MAPPING FOR PUBLIC SERVER srv_inventarios
    OPTIONS (user 'usr_inventario_auditor', password 'Invent#Audi_2026', password_required 'false');
CREATE USER MAPPING FOR PUBLIC SERVER srv_ventas
    OPTIONS (user 'usr_ventas_auditor', password 'Ventas#Audi_2026', password_required 'false');
CREATE USER MAPPING FOR PUBLIC SERVER srv_identidad
    OPTIONS (user 'usr_identidad_auditor', password 'Identidad#Auditor_2026', password_required 'false');

-- Importación automática de tablas padre y catálogos por esquema de microservicio
IMPORT FOREIGN SCHEMA public FROM SERVER srv_catalogo    INTO catalogo_terceros;
IMPORT FOREIGN SCHEMA public FROM SERVER srv_compras     INTO compras_abastecimiento;
IMPORT FOREIGN SCHEMA public FROM SERVER srv_inventarios INTO inventarios_transferencias;
IMPORT FOREIGN SCHEMA public FROM SERVER srv_ventas      INTO ventas_pagos;
-- Por mínimo privilegio, identidad expone empleados y auditoria_accesos (sin password_hash de usuarios)
IMPORT FOREIGN SCHEMA public LIMIT TO (empleados, auditoria_accesos)
    FROM SERVER srv_identidad INTO identidad_accesos;

-- Tablas externas explícitas para las particiones físicas por sede (IMPORT FOREIGN SCHEMA omite particiones hijas)
CREATE FOREIGN TABLE IF NOT EXISTS inventarios_transferencias.inventarios_sede_1 (
    id_sede INT, id_almacen INT, id_producto INT,
    existencia_actual INT, stock_minimo INT, fecha_actualizacion DATE
) SERVER srv_inventarios OPTIONS (schema_name 'public', table_name 'inventarios_sede_1');

CREATE FOREIGN TABLE IF NOT EXISTS inventarios_transferencias.inventarios_sede_2 (
    id_sede INT, id_almacen INT, id_producto INT,
    existencia_actual INT, stock_minimo INT, fecha_actualizacion DATE
) SERVER srv_inventarios OPTIONS (schema_name 'public', table_name 'inventarios_sede_2');

CREATE FOREIGN TABLE IF NOT EXISTS inventarios_transferencias.inventarios_sede_3 (
    id_sede INT, id_almacen INT, id_producto INT,
    existencia_actual INT, stock_minimo INT, fecha_actualizacion DATE
) SERVER srv_inventarios OPTIONS (schema_name 'public', table_name 'inventarios_sede_3');

CREATE FOREIGN TABLE IF NOT EXISTS inventarios_transferencias.inventarios_sede_4 (
    id_sede INT, id_almacen INT, id_producto INT,
    existencia_actual INT, stock_minimo INT, fecha_actualizacion DATE
) SERVER srv_inventarios OPTIONS (schema_name 'public', table_name 'inventarios_sede_4');

CREATE FOREIGN TABLE IF NOT EXISTS inventarios_transferencias.inventarios_sede_5 (
    id_sede INT, id_almacen INT, id_producto INT,
    existencia_actual INT, stock_minimo INT, fecha_actualizacion DATE
) SERVER srv_inventarios OPTIONS (schema_name 'public', table_name 'inventarios_sede_5');

CREATE FOREIGN TABLE IF NOT EXISTS ventas_pagos.pedidos_venta_sede_1 (
    id_pedido INT, id_sede INT, id_almacen INT, id_cliente INT,
    id_empleado INT, fecha_pedido DATE, estado VARCHAR(20), total_registrado NUMERIC(12,2)
) SERVER srv_ventas OPTIONS (schema_name 'public', table_name 'pedidos_venta_sede_1');

CREATE FOREIGN TABLE IF NOT EXISTS ventas_pagos.pedidos_venta_sede_2 (
    id_pedido INT, id_sede INT, id_almacen INT, id_cliente INT,
    id_empleado INT, fecha_pedido DATE, estado VARCHAR(20), total_registrado NUMERIC(12,2)
) SERVER srv_ventas OPTIONS (schema_name 'public', table_name 'pedidos_venta_sede_2');

CREATE FOREIGN TABLE IF NOT EXISTS ventas_pagos.pedidos_venta_sede_3 (
    id_pedido INT, id_sede INT, id_almacen INT, id_cliente INT,
    id_empleado INT, fecha_pedido DATE, estado VARCHAR(20), total_registrado NUMERIC(12,2)
) SERVER srv_ventas OPTIONS (schema_name 'public', table_name 'pedidos_venta_sede_3');

CREATE FOREIGN TABLE IF NOT EXISTS ventas_pagos.pedidos_venta_sede_4 (
    id_pedido INT, id_sede INT, id_almacen INT, id_cliente INT,
    id_empleado INT, fecha_pedido DATE, estado VARCHAR(20), total_registrado NUMERIC(12,2)
) SERVER srv_ventas OPTIONS (schema_name 'public', table_name 'pedidos_venta_sede_4');

CREATE FOREIGN TABLE IF NOT EXISTS ventas_pagos.pedidos_venta_sede_5 (
    id_pedido INT, id_sede INT, id_almacen INT, id_cliente INT,
    id_empleado INT, fecha_pedido DATE, estado VARCHAR(20), total_registrado NUMERIC(12,2)
) SERVER srv_ventas OPTIONS (schema_name 'public', table_name 'pedidos_venta_sede_5');

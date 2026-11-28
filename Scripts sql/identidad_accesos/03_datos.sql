-- ============================================================================
-- MICROSERVICIO: identidad_accesos
-- 03. Datos de prueba reproducibles
-- Motor: PostgreSQL 18 / Neon
-- ----------------------------------------------------------------------------
-- Volúmenes: Empleados 25 | Usuarios 25 | Auditoría 1500 (propuesta delimitada)
-- Distribución de cargos/roles:
--   Administrador 1 | Gerencia 2 | Inventario 5 (uno por sede) | Compras 2
--   Vendedor 13 | Auditor 2  -> Total 25
-- NOTA: id_sede referencia lógicamente a catalogo_terceros.sedes (sedes 1..5).
-- ============================================================================

TRUNCATE TABLE auditoria_accesos, usuarios, empleados RESTART IDENTITY CASCADE;

-- ---------------------- Empleados: 25 --------------------------------------
INSERT INTO empleados (id_empleado, id_sede, num_documento, nombre_completo, cargo, correo, estado)
SELECT
    g,
    CASE
        WHEN g BETWEEN 4 AND 8 THEN g - 3        -- inventario: sede 1..5 (uno por sede)
        ELSE ((g - 1) % 5) + 1
    END,
    79000000 + g * 53,
    'Empleado ' || g || ' Apellido',
    CASE
        WHEN g = 1               THEN 'Administrador'
        WHEN g BETWEEN 2 AND 3   THEN 'Gerencia'
        WHEN g BETWEEN 4 AND 8   THEN 'Jefe de Inventario'
        WHEN g BETWEEN 9 AND 10  THEN 'Jefe de Compras'
        WHEN g BETWEEN 11 AND 23 THEN 'Vendedor'
        ELSE 'Auditor'
    END,
    'empleado' || g || '@empresa.com',
    CASE WHEN g <> 1 AND g % 12 = 0 THEN 'Inactivo' ELSE 'Activo' END
FROM generate_series(1, 25) AS g;

-- ---------------------- Usuarios: 25 ---------------------------------------
INSERT INTO usuarios (id_usuario, id_empleado, nombre_usuario, password_hash, rol, estado, fecha_creacion)
SELECT
    e.id_empleado,
    e.id_empleado,
    'user' || e.id_empleado,
    '$2b$10$' || md5('pwd' || e.id_empleado) || '00000',
    CASE e.cargo
        WHEN 'Administrador'      THEN 'Administrador'
        WHEN 'Gerencia'           THEN 'Gerencia'
        WHEN 'Jefe de Inventario' THEN 'Inventario'
        WHEN 'Jefe de Compras'    THEN 'Compras'
        WHEN 'Vendedor'           THEN 'Vendedor'
        WHEN 'Auditor'            THEN 'Auditor'
    END,
    e.estado,
    DATE '2026-07-01' + (e.id_empleado % 25)
FROM empleados e;

-- ---------------------- Auditoría de accesos: 1500 -------------------------
INSERT INTO auditoria_accesos (id_auditoria, id_usuario, fecha_hora, accion, objeto_consultado)
SELECT
    g,
    ((g - 1) % 25) + 1,
    TIMESTAMP '2026-07-28 08:00:00' + ((g % 120) * INTERVAL '1 day') + ((g % 10) * INTERVAL '1 hour'),
    (ARRAY['LOGIN','CONSULTA','EXPORTA','ACTUALIZA','INSERTA'])[((g - 1) % 5) + 1],
    (ARRAY[
        'ventas_pagos.pedidos_venta',
        'compras_abastecimiento.ordenes_compra',
        'inventarios_transferencias.inventarios',
        'catalogo_terceros.productos',
        'reportes.vista_reporte_corporativo'
    ])[((g - 1) % 5) + 1]
FROM generate_series(1, 1500) AS g;

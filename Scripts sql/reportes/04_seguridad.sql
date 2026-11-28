-- ============================================================================
-- MICROSERVICIO: reportes
-- 04. Seguridad: roles de lectura corporativa y permisos sobre vistas y FDW
-- Motor: PostgreSQL 18 / Neon
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes_admin') THEN
        CREATE ROLE rol_reportes_admin;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes_gerencia') THEN
        CREATE ROLE rol_reportes_gerencia;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes_auditor') THEN
        CREATE ROLE rol_reportes_auditor;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes_lector') THEN
        CREATE ROLE rol_reportes_lector;
    END IF;
END $$;

-- Admin de reportes: gestiona vistas en `reportes` y lee los esquemas FDW
GRANT USAGE, CREATE ON SCHEMA reportes TO rol_reportes_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA reportes TO rol_reportes_admin;
GRANT USAGE ON SCHEMA catalogo_terceros, compras_abastecimiento,
    inventarios_transferencias, ventas_pagos, identidad_accesos TO rol_reportes_admin;
GRANT SELECT ON ALL TABLES IN SCHEMA catalogo_terceros, compras_abastecimiento,
    inventarios_transferencias, ventas_pagos, identidad_accesos TO rol_reportes_admin;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA
    catalogo_terceros, compras_abastecimiento, inventarios_transferencias,
    ventas_pagos, identidad_accesos FROM rol_reportes_admin;

-- Gerencia, Auditor y Lector (incluida la cuenta de servicio usr_reportes_app):
-- solo lectura exclusivamente sobre las vistas del esquema `reportes`
GRANT USAGE ON SCHEMA reportes TO rol_reportes_gerencia, rol_reportes_auditor, rol_reportes_lector;
GRANT SELECT ON ALL TABLES IN SCHEMA reportes TO rol_reportes_gerencia, rol_reportes_auditor, rol_reportes_lector;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA reportes
    FROM rol_reportes_gerencia, rol_reportes_auditor, rol_reportes_lector;
REVOKE ALL ON SCHEMA catalogo_terceros, compras_abastecimiento,
    inventarios_transferencias, ventas_pagos, identidad_accesos
    FROM rol_reportes_gerencia, rol_reportes_auditor, rol_reportes_lector;

-- Usuarios de login
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_reportes_admin') THEN
        CREATE USER usr_reportes_admin WITH PASSWORD 'Reportes#Admin_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_reportes_gerencia') THEN
        CREATE USER usr_reportes_gerencia WITH PASSWORD 'Reportes#Geren_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_reportes_auditor') THEN
        CREATE USER usr_reportes_auditor WITH PASSWORD 'Reportes#Audi_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_reportes_lector') THEN
        CREATE USER usr_reportes_lector WITH PASSWORD 'Reportes#Lector_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_reportes_app') THEN
        CREATE USER usr_reportes_app WITH PASSWORD 'Reportes#App_2026';
    END IF;
END $$;

GRANT rol_reportes_admin    TO usr_reportes_admin;
GRANT rol_reportes_gerencia TO usr_reportes_gerencia;
GRANT rol_reportes_auditor  TO usr_reportes_auditor;
GRANT rol_reportes_lector   TO usr_reportes_lector;
GRANT rol_reportes_lector   TO usr_reportes_app;

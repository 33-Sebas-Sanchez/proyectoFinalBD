-- ============================================================================
-- MICROSERVICIO: ventas_pagos
-- 04. Seguridad: roles, usuarios, permisos (GRANT/REVOKE) de ESTA base de datos
-- Motor: PostgreSQL 18 / Neon
-- ============================================================================

-- --------------------------- Roles de grupo (idempotente) -------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_ventas_admin') THEN
        CREATE ROLE rol_ventas_admin;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_ventas_vendedor') THEN
        CREATE ROLE rol_ventas_vendedor;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_ventas_gerencia') THEN
        CREATE ROLE rol_ventas_gerencia;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_ventas_auditor') THEN
        CREATE ROLE rol_ventas_auditor;
    END IF;
END $$;

-- --------------------------- Permisos: ADMIN -------------------------------
GRANT USAGE, CREATE ON SCHEMA public TO rol_ventas_admin;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO rol_ventas_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rol_ventas_admin;

-- --------------------------- Permisos: VENDEDOR (S/I/U sin DELETE) ---------
GRANT USAGE ON SCHEMA public TO rol_ventas_vendedor;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO rol_ventas_vendedor;
REVOKE DELETE ON ALL TABLES IN SCHEMA public FROM rol_ventas_vendedor;

-- --------------------------- Permisos: GERENCIA (lectura) ------------------
GRANT USAGE ON SCHEMA public TO rol_ventas_gerencia;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_ventas_gerencia;
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM rol_ventas_gerencia;

-- --------------------------- Permisos: AUDITOR (lectura) -------------------
GRANT USAGE ON SCHEMA public TO rol_ventas_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_ventas_auditor;
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM rol_ventas_auditor;

-- --------------------------- Usuarios de login (idempotente) ---------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_ventas_admin') THEN
        CREATE USER usr_ventas_admin WITH PASSWORD 'Ventas#Admin_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_ventas_vendedor') THEN
        CREATE USER usr_ventas_vendedor WITH PASSWORD 'Ventas#Vend_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_ventas_gerencia') THEN
        CREATE USER usr_ventas_gerencia WITH PASSWORD 'Ventas#Geren_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_ventas_auditor') THEN
        CREATE USER usr_ventas_auditor WITH PASSWORD 'Ventas#Audi_2026';
    END IF;
END $$;

GRANT rol_ventas_admin    TO usr_ventas_admin;
GRANT rol_ventas_vendedor TO usr_ventas_vendedor;
GRANT rol_ventas_gerencia TO usr_ventas_gerencia;
GRANT rol_ventas_auditor  TO usr_ventas_auditor;

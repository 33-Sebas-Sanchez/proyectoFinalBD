-- ============================================================================
-- MICROSERVICIO: inventarios_transferencias
-- 04. Seguridad: roles, usuarios, permisos (GRANT/REVOKE) de ESTA base de datos
-- Motor: PostgreSQL 18 / Neon
-- ============================================================================

-- --------------------------- Roles de grupo (idempotente) -------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_inventario_admin') THEN
        CREATE ROLE rol_inventario_admin;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_inventario_operador') THEN
        CREATE ROLE rol_inventario_operador;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_inventario_auditor') THEN
        CREATE ROLE rol_inventario_auditor;
    END IF;
END $$;

-- --------------------------- Permisos: ADMIN -------------------------------
GRANT USAGE, CREATE ON SCHEMA public TO rol_inventario_admin;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO rol_inventario_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rol_inventario_admin;

-- --------------------------- Permisos: OPERADOR ----------------------------
GRANT USAGE ON SCHEMA public TO rol_inventario_operador;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO rol_inventario_operador;

-- --------------------------- Permisos: AUDITOR -----------------------------
GRANT USAGE ON SCHEMA public TO rol_inventario_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_inventario_auditor;
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM rol_inventario_auditor;

-- --------------------------- Usuarios de login (idempotente) ---------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_inventario_admin') THEN
        CREATE USER usr_inventario_admin WITH PASSWORD 'Invent#Admin_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_inventario_operador') THEN
        CREATE USER usr_inventario_operador WITH PASSWORD 'Invent#Oper_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_inventario_auditor') THEN
        CREATE USER usr_inventario_auditor WITH PASSWORD 'Invent#Audi_2026';
    END IF;
END $$;

GRANT rol_inventario_admin    TO usr_inventario_admin;
GRANT rol_inventario_operador TO usr_inventario_operador;
GRANT rol_inventario_auditor  TO usr_inventario_auditor;

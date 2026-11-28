-- ============================================================================
-- MICROSERVICIO: identidad_accesos
-- 04. Seguridad: roles, usuarios, permisos (GRANT/REVOKE) de ESTA base de datos
-- Motor: PostgreSQL 18 / Neon
-- ============================================================================

-- --------------------------- Roles de grupo (idempotente) -------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_identidad_admin') THEN
        CREATE ROLE rol_identidad_admin;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_identidad_auditor') THEN
        CREATE ROLE rol_identidad_auditor;
    END IF;
END $$;

-- --------------------------- Permisos: ADMIN -------------------------------
GRANT USAGE, CREATE ON SCHEMA public TO rol_identidad_admin;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO rol_identidad_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rol_identidad_admin;
-- La bitácora de auditoría es estrictamente append-only: incluso el admin no puede alterar ni borrar registros
REVOKE UPDATE, DELETE, TRUNCATE ON auditoria_accesos FROM PUBLIC, rol_identidad_admin, rol_identidad_auditor;

-- --------------------------- Permisos: AUDITOR -----------------------------
GRANT USAGE ON SCHEMA public TO rol_identidad_auditor;
GRANT SELECT ON empleados          TO rol_identidad_auditor;
GRANT SELECT ON auditoria_accesos  TO rol_identidad_auditor;
REVOKE SELECT ON usuarios          FROM rol_identidad_auditor;
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM rol_identidad_auditor;

-- --------------------------- Usuarios de login (idempotente) ---------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_identidad_admin') THEN
        CREATE USER usr_identidad_admin WITH PASSWORD 'Identidad#Admin_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_identidad_auditor') THEN
        CREATE USER usr_identidad_auditor WITH PASSWORD 'Identidad#Auditor_2026';
    END IF;
END $$;

GRANT rol_identidad_admin   TO usr_identidad_admin;
GRANT rol_identidad_auditor TO usr_identidad_auditor;

-- ============================================================================
-- MICROSERVICIO: compras_abastecimiento
-- 04. Seguridad: roles, usuarios, permisos (GRANT/REVOKE) de ESTA base de datos
-- Motor: PostgreSQL 18 / Neon
-- ============================================================================

-- --------------------------- Roles de grupo (idempotente) -------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_compras_admin') THEN
        CREATE ROLE rol_compras_admin;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_compras_operador') THEN
        CREATE ROLE rol_compras_operador;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_compras_auditor') THEN
        CREATE ROLE rol_compras_auditor;
    END IF;
END $$;

-- --------------------------- Permisos: ADMIN -------------------------------
GRANT USAGE, CREATE ON SCHEMA public TO rol_compras_admin;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO rol_compras_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rol_compras_admin;

-- --------------------------- Permisos: OPERADOR ----------------------------
GRANT USAGE ON SCHEMA public TO rol_compras_operador;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO rol_compras_operador;
REVOKE DELETE ON ALL TABLES IN SCHEMA public FROM rol_compras_operador;

-- --------------------------- Permisos: AUDITOR -----------------------------
GRANT USAGE ON SCHEMA public TO rol_compras_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_compras_auditor;
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM rol_compras_auditor;

-- --------------------------- Usuarios de login (idempotente) ---------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_compras_admin') THEN
        CREATE USER usr_compras_admin WITH PASSWORD 'Compras#Admin_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_compras_operador') THEN
        CREATE USER usr_compras_operador WITH PASSWORD 'Compras#Oper_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_compras_auditor') THEN
        CREATE USER usr_compras_auditor WITH PASSWORD 'Compras#Audi_2026';
    END IF;
END $$;

GRANT rol_compras_admin    TO usr_compras_admin;
GRANT rol_compras_operador TO usr_compras_operador;
GRANT rol_compras_auditor  TO usr_compras_auditor;

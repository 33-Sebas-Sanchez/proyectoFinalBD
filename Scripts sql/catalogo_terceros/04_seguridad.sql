-- ============================================================================
-- MICROSERVICIO: catalogo_terceros
-- 04. Seguridad: roles, usuarios, permisos (GRANT/REVOKE) de ESTA base de datos
-- Motor: PostgreSQL 18 / Neon
-- ============================================================================

-- --------------------------- Roles de grupo (idempotente) -------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_catalogo_admin') THEN
        CREATE ROLE rol_catalogo_admin;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_catalogo_lector') THEN
        CREATE ROLE rol_catalogo_lector;
    END IF;
END $$;

-- --------------------------- Permisos: ADMIN -------------------------------
GRANT USAGE, CREATE ON SCHEMA public TO rol_catalogo_admin;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO rol_catalogo_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rol_catalogo_admin;

-- --------------------------- Permisos: LECTOR ------------------------------
GRANT USAGE ON SCHEMA public TO rol_catalogo_lector;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_catalogo_lector;
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM rol_catalogo_lector;

-- --------------------------- Usuarios de login (idempotente) ---------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_catalogo_admin') THEN
        CREATE USER usr_catalogo_admin WITH PASSWORD 'Catalogo#Admin_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_catalogo_lector') THEN
        CREATE USER usr_catalogo_lector WITH PASSWORD 'Catalogo#Lector_2026';
    END IF;
END $$;

GRANT rol_catalogo_admin  TO usr_catalogo_admin;
GRANT rol_catalogo_lector TO usr_catalogo_lector;

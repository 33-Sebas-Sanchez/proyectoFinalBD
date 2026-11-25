-- ============================================================================
-- MICROSERVICIO: catalogo_terceros
-- 04. Seguridad: roles, usuarios, permisos (GRANT/REVOKE) de ESTA instancia
-- Motor: PostgreSQL (Neon)
-- ----------------------------------------------------------------------------
-- Principio microservicios: cada servicio es DUEÑO de sus roles. Este servicio
-- es el "catálogo maestro"; es consultado por otros servicios, así que expone
-- un rol de LECTURA (para integraciones) además de su rol administrador.
--
-- Roles de este servicio:
--   rol_catalogo_admin  -> gestiona todo el catálogo (lectura+escritura)
--   rol_catalogo_lector -> solo lectura (lo usan integraciones de otros servicios)

-- ============================================================================

-- --------------------------- Roles de grupo --------------------------------
CREATE ROLE rol_catalogo_admin;
CREATE ROLE rol_catalogo_lector;

-- --------------------------- Permisos: ADMIN -------------------------------
GRANT USAGE, CREATE ON SCHEMA public TO rol_catalogo_admin;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO rol_catalogo_admin;

-- --------------------------- Permisos: LECTOR ------------------------------
GRANT USAGE ON SCHEMA public TO rol_catalogo_lector;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_catalogo_lector;

-- --------------------------- Usuarios de login -----------------------------
CREATE USER usr_catalogo_admin  WITH PASSWORD 'Catalogo#Admin_2026';
CREATE USER usr_catalogo_lector WITH PASSWORD 'Catalogo#Lector_2026';
GRANT rol_catalogo_admin  TO usr_catalogo_admin;
GRANT rol_catalogo_lector TO usr_catalogo_lector;

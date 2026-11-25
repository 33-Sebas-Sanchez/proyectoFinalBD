-- ============================================================================
-- MICROSERVICIO: identidad_accesos
-- 04. Seguridad: roles, usuarios, permisos (GRANT/REVOKE) de ESTA instancia
-- Motor: PostgreSQL (Neon)
-- ----------------------------------------------------------------------------
-- Roles de este servicio:
--   rol_identidad_admin   -> gestiona empleados/usuarios (lectura+escritura)
--   rol_identidad_auditor -> solo lectura, para la función de auditoría
-- ============================================================================

-- --------------------------- Roles de grupo --------------------------------
CREATE ROLE rol_identidad_admin;
CREATE ROLE rol_identidad_auditor;

-- --------------------------- Permisos: ADMIN -------------------------------
GRANT USAGE, CREATE ON SCHEMA public TO rol_identidad_admin;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO rol_identidad_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rol_identidad_admin;

-- --------------------------- Permisos: AUDITOR -----------------------------
GRANT USAGE ON SCHEMA public TO rol_identidad_auditor;
GRANT SELECT ON empleados          TO rol_identidad_auditor;
GRANT SELECT ON auditoria_accesos  TO rol_identidad_auditor;

-- --------------------------- Usuarios de login -----------------------------
CREATE USER usr_identidad_admin   WITH PASSWORD 'Identidad#Admin_2026';
CREATE USER usr_identidad_auditor WITH PASSWORD 'Identidad#Auditor_2026';
GRANT rol_identidad_admin   TO usr_identidad_admin;
GRANT rol_identidad_auditor TO usr_identidad_auditor;

-- --------------------------- REVOKE -----------------------------
REVOKE SELECT ON usuarios FROM rol_identidad_auditor;

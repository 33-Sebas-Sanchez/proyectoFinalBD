-- ============================================================================
-- MICROSERVICIO: inventarios_transferencias
-- 04. Seguridad: roles, usuarios, permisos (GRANT/REVOKE) de ESTA instancia
-- Motor: PostgreSQL (Neon)
-- ----------------------------------------------------------------------------
-- Roles de este servicio:
--   rol_inventario_admin    -> gestiona todo el servicio de inventarios
--   rol_inventario_operador -> ajusta existencias y transferencias (CRUD acotado)
--   rol_inventario_auditor  -> solo lectura
-- ============================================================================

-- --------------------------- Roles de grupo --------------------------------
CREATE ROLE rol_inventario_admin;
CREATE ROLE rol_inventario_operador;
CREATE ROLE rol_inventario_auditor;

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

-- --------------------------- Usuarios de login -----------------------------
CREATE USER usr_inventario_admin    WITH PASSWORD 'Invent#Admin_2026';
CREATE USER usr_inventario_operador WITH PASSWORD 'Invent#Oper_2026';
CREATE USER usr_inventario_auditor  WITH PASSWORD 'Invent#Audi_2026';
GRANT rol_inventario_admin    TO usr_inventario_admin;
GRANT rol_inventario_operador TO usr_inventario_operador;
GRANT rol_inventario_auditor  TO usr_inventario_auditor;

-- --------------------------- REVOKE -----------------------------
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM rol_inventario_auditor;

-- ============================================================================
-- MICROSERVICIO: compras_abastecimiento
-- 04. Seguridad: roles, usuarios, permisos (GRANT/REVOKE) de ESTA instancia
-- Motor: PostgreSQL (Neon)
-- ----------------------------------------------------------------------------
-- Roles de este servicio:
--   rol_compras_admin    -> gestiona todo el servicio de compras
--   rol_compras_operador -> registra órdenes/recepciones (SELECT/INSERT/UPDATE)
--   rol_compras_auditor  -> solo lectura
-- ============================================================================

-- --------------------------- Roles de grupo --------------------------------
CREATE ROLE rol_compras_admin;
CREATE ROLE rol_compras_operador;
CREATE ROLE rol_compras_auditor;

-- --------------------------- Permisos: ADMIN -------------------------------
GRANT USAGE, CREATE ON SCHEMA public TO rol_compras_admin;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO rol_compras_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rol_compras_admin;

-- --------------------------- Permisos: OPERADOR ----------------------------
GRANT USAGE ON SCHEMA public TO rol_compras_operador;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO rol_compras_operador;

-- --------------------------- Permisos: AUDITOR -----------------------------
GRANT USAGE ON SCHEMA public TO rol_compras_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_compras_auditor;

-- --------------------------- Usuarios de login -----------------------------
CREATE USER usr_compras_admin    WITH PASSWORD 'Compras#Admin_2026';
CREATE USER usr_compras_operador WITH PASSWORD 'Compras#Oper_2026';
CREATE USER usr_compras_auditor  WITH PASSWORD 'Compras#Audi_2026';
GRANT rol_compras_admin    TO usr_compras_admin;
GRANT rol_compras_operador TO usr_compras_operador;
GRANT rol_compras_auditor  TO usr_compras_auditor;


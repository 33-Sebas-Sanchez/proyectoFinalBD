-- ============================================================================
-- MICROSERVICIO: ventas_pagos
-- 04. Seguridad: roles, usuarios, permisos (GRANT/REVOKE) de ESTA instancia
-- Motor: PostgreSQL (Neon)
-- ----------------------------------------------------------------------------
-- Roles de este servicio:
--   rol_ventas_admin    -> gestiona todo el servicio de ventas
--   rol_ventas_vendedor -> registra pedidos/pagos/devoluciones (CRUD acotado)
--   rol_ventas_gerencia -> solo lectura con visión de negocio
--   rol_ventas_auditor  -> solo lectura
-- ============================================================================

-- --------------------------- Roles de grupo --------------------------------
CREATE ROLE rol_ventas_admin;
CREATE ROLE rol_ventas_vendedor;
CREATE ROLE rol_ventas_gerencia;
CREATE ROLE rol_ventas_auditor;

-- --------------------------- Permisos: ADMIN -------------------------------
GRANT USAGE, CREATE ON SCHEMA public TO rol_ventas_admin;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO rol_ventas_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rol_ventas_admin;

-- --------------------------- Permisos: VENDEDOR ----------------------------
GRANT USAGE ON SCHEMA public TO rol_ventas_vendedor;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO rol_ventas_vendedor;

-- --------------------------- Permisos: GERENCIA (lectura) ------------------
GRANT USAGE ON SCHEMA public TO rol_ventas_gerencia;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_ventas_gerencia;

-- --------------------------- Permisos: AUDITOR (lectura) -------------------
GRANT USAGE ON SCHEMA public TO rol_ventas_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_ventas_auditor;

-- --------------------------- Usuarios de login -----------------------------
CREATE USER usr_ventas_admin    WITH PASSWORD 'Ventas#Admin_2026';
CREATE USER usr_ventas_vendedor WITH PASSWORD 'Ventas#Vend_2026';
CREATE USER usr_ventas_gerencia WITH PASSWORD 'Ventas#Geren_2026';
CREATE USER usr_ventas_auditor  WITH PASSWORD 'Ventas#Audi_2026';
GRANT rol_ventas_admin    TO usr_ventas_admin;
GRANT rol_ventas_vendedor TO usr_ventas_vendedor;
GRANT rol_ventas_gerencia TO usr_ventas_gerencia;
GRANT rol_ventas_auditor  TO usr_ventas_auditor;

-- ---------------------------REVOKE -----------------------------
REVOKE DELETE ON ALL TABLES IN SCHEMA public FROM rol_ventas_vendedor;

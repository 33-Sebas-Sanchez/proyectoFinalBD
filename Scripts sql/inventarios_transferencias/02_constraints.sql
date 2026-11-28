-- ============================================================================
-- MICROSERVICIO: inventarios_transferencias
-- 02. Restricciones (ALTER TABLE / ALTER COLUMN) + claves foráneas INTERNAS
-- Motor: PostgreSQL 18 / Neon
-- ============================================================================

-- ---------------------- inventarios (particionada por id_sede) -------------
ALTER TABLE inventarios ALTER COLUMN id_sede             SET NOT NULL;
ALTER TABLE inventarios ALTER COLUMN id_almacen          SET NOT NULL;
ALTER TABLE inventarios ALTER COLUMN id_producto         SET NOT NULL;
ALTER TABLE inventarios ALTER COLUMN existencia_actual   SET NOT NULL;
ALTER TABLE inventarios ALTER COLUMN stock_minimo        SET NOT NULL;
ALTER TABLE inventarios ALTER COLUMN fecha_actualizacion SET NOT NULL;
-- PostgreSQL exige que la PK de una tabla particionada incluya la clave de partición (id_sede)
ALTER TABLE inventarios ADD CONSTRAINT pk_inventarios PRIMARY KEY (id_sede, id_almacen, id_producto);
ALTER TABLE inventarios ADD CONSTRAINT ck_inventarios_existencia CHECK (existencia_actual >= 0);
ALTER TABLE inventarios ADD CONSTRAINT ck_inventarios_stock_minimo CHECK (stock_minimo >= 0);

-- ---------------------- transferencias -------------------------------------
ALTER TABLE transferencias ALTER COLUMN id_almacen_origen  SET NOT NULL;
ALTER TABLE transferencias ALTER COLUMN id_almacen_destino SET NOT NULL;
ALTER TABLE transferencias ALTER COLUMN fecha_solicitud    SET NOT NULL;
ALTER TABLE transferencias ALTER COLUMN estado             SET NOT NULL;
ALTER TABLE transferencias ADD CONSTRAINT pk_transferencias PRIMARY KEY (id_transferencia);
ALTER TABLE transferencias ADD CONSTRAINT ck_transferencias_estado CHECK (estado IN ('Solicitada', 'Despachada', 'Recibida', 'Cancelada'));
ALTER TABLE transferencias ADD CONSTRAINT ck_transferencias_almacenes CHECK (id_almacen_origen <> id_almacen_destino);
ALTER TABLE transferencias ADD CONSTRAINT ck_transferencias_fechas
    CHECK (
        (fecha_despacho IS NULL OR fecha_despacho >= fecha_solicitud)
        AND (fecha_recepcion IS NULL OR (fecha_despacho IS NOT NULL AND fecha_recepcion >= fecha_despacho))
    );

-- ---------------------- detalle_transferencia ------------------------------
ALTER TABLE detalle_transferencia ALTER COLUMN id_transferencia SET NOT NULL;
ALTER TABLE detalle_transferencia ALTER COLUMN id_producto      SET NOT NULL;
ALTER TABLE detalle_transferencia ALTER COLUMN cantidad_enviada SET NOT NULL;
ALTER TABLE detalle_transferencia ADD CONSTRAINT pk_detalle_transferencia PRIMARY KEY (id_transferencia, id_producto);
ALTER TABLE detalle_transferencia ADD CONSTRAINT ck_detalle_transferencia_enviada CHECK (cantidad_enviada > 0);
ALTER TABLE detalle_transferencia ADD CONSTRAINT ck_detalle_transferencia_recibida CHECK (cantidad_recibida IS NULL OR cantidad_recibida >= 0);
-- FK INTERNA
ALTER TABLE detalle_transferencia ADD CONSTRAINT fk_detalle_transferencia_transferencia
    FOREIGN KEY (id_transferencia) REFERENCES transferencias (id_transferencia);

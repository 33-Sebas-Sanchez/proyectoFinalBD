-- ============================================================================
-- MICROSERVICIO: compras_abastecimiento
-- 02. Restricciones (ALTER TABLE / ALTER COLUMN) + claves foráneas INTERNAS
-- Motor: PostgreSQL (Neon)
-- ============================================================================

-- ---------------------- ordenes_compra -------------------------------------
ALTER TABLE ordenes_compra ALTER COLUMN id_proveedor       SET NOT NULL;
ALTER TABLE ordenes_compra ALTER COLUMN id_almacen_destino SET NOT NULL;
ALTER TABLE ordenes_compra ALTER COLUMN id_empleado        SET NOT NULL;
ALTER TABLE ordenes_compra ALTER COLUMN fecha_orden        SET NOT NULL;
ALTER TABLE ordenes_compra ALTER COLUMN fecha_estimada     SET NOT NULL;
ALTER TABLE ordenes_compra ALTER COLUMN estado             SET NOT NULL;
ALTER TABLE ordenes_compra ADD CONSTRAINT pk_ordenes_compra PRIMARY KEY (id_orden_compra);
ALTER TABLE ordenes_compra ADD CONSTRAINT ck_ordenes_compra_fecha CHECK (fecha_estimada >= fecha_orden);
ALTER TABLE ordenes_compra ADD CONSTRAINT ck_ordenes_compra_estado CHECK (estado IN ('Pendiente', 'Recibida Parcial', 'Recibida Total', 'Cancelada'));

-- ---------------------- detalle_orden_compra -------------------------------
ALTER TABLE detalle_orden_compra ALTER COLUMN id_orden_compra     SET NOT NULL;
ALTER TABLE detalle_orden_compra ALTER COLUMN id_producto         SET NOT NULL;
ALTER TABLE detalle_orden_compra ALTER COLUMN cantidad_solicitada SET NOT NULL;
ALTER TABLE detalle_orden_compra ALTER COLUMN costo_unitario      SET NOT NULL;
ALTER TABLE detalle_orden_compra ADD CONSTRAINT pk_detalle_orden_compra PRIMARY KEY (id_orden_compra, id_producto);
ALTER TABLE detalle_orden_compra ADD CONSTRAINT ck_detalle_orden_compra_cantidad CHECK (cantidad_solicitada > 0);
ALTER TABLE detalle_orden_compra ADD CONSTRAINT ck_detalle_orden_compra_costo CHECK (costo_unitario >= 0);
-- FK INTERNA
ALTER TABLE detalle_orden_compra ADD CONSTRAINT fk_detalle_oc_orden
    FOREIGN KEY (id_orden_compra) REFERENCES ordenes_compra (id_orden_compra);

-- ---------------------- recepciones_compra ---------------------------------
ALTER TABLE recepciones_compra ALTER COLUMN id_orden_compra SET NOT NULL;
ALTER TABLE recepciones_compra ALTER COLUMN fecha_recepcion SET NOT NULL;
ALTER TABLE recepciones_compra ALTER COLUMN estado          SET NOT NULL;
ALTER TABLE recepciones_compra ADD CONSTRAINT pk_recepciones_compra PRIMARY KEY (id_recepcion);
ALTER TABLE recepciones_compra ADD CONSTRAINT ck_recepciones_compra_estado CHECK (estado IN ('Procesado', 'Parcial', 'Anulado'));
-- FK INTERNA
ALTER TABLE recepciones_compra ADD CONSTRAINT fk_recepciones_orden
    FOREIGN KEY (id_orden_compra) REFERENCES ordenes_compra (id_orden_compra);

-- ---------------------- detalle_recepcion ----------------------------------
ALTER TABLE detalle_recepcion ALTER COLUMN id_recepcion      SET NOT NULL;
ALTER TABLE detalle_recepcion ALTER COLUMN id_producto       SET NOT NULL;
ALTER TABLE detalle_recepcion ALTER COLUMN cantidad_recibida SET NOT NULL;
ALTER TABLE detalle_recepcion ADD CONSTRAINT pk_detalle_recepcion PRIMARY KEY (id_recepcion, id_producto);
ALTER TABLE detalle_recepcion ADD CONSTRAINT ck_detalle_recepcion_cantidad CHECK (cantidad_recibida >= 0);
-- FK INTERNA
ALTER TABLE detalle_recepcion ADD CONSTRAINT fk_detalle_recepcion_recepcion
    FOREIGN KEY (id_recepcion) REFERENCES recepciones_compra (id_recepcion);

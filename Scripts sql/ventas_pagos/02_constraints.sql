-- ============================================================================
-- MICROSERVICIO: ventas_pagos
-- 02. Restricciones (ALTER TABLE / ALTER COLUMN) + claves foráneas INTERNAS
-- Motor: PostgreSQL (Neon)
-- ============================================================================

-- ---------------------- pedidos_venta --------------------------------------
ALTER TABLE pedidos_venta ALTER COLUMN id_sede          SET NOT NULL;
ALTER TABLE pedidos_venta ALTER COLUMN id_almacen       SET NOT NULL;
ALTER TABLE pedidos_venta ALTER COLUMN id_cliente       SET NOT NULL;
ALTER TABLE pedidos_venta ALTER COLUMN id_empleado      SET NOT NULL;
ALTER TABLE pedidos_venta ALTER COLUMN fecha_pedido     SET NOT NULL;
ALTER TABLE pedidos_venta ALTER COLUMN estado           SET NOT NULL;
ALTER TABLE pedidos_venta ALTER COLUMN total_registrado SET NOT NULL;
ALTER TABLE pedidos_venta ADD CONSTRAINT pk_pedidos_venta PRIMARY KEY (id_pedido);
ALTER TABLE pedidos_venta ADD CONSTRAINT ck_pedidos_venta_estado CHECK (estado IN ('Pendiente', 'Completado', 'Cancelado'));
ALTER TABLE pedidos_venta ADD CONSTRAINT ck_pedidos_venta_total CHECK (total_registrado >= 0);

-- ---------------------- detalle_pedido -------------------------------------
ALTER TABLE detalle_pedido ALTER COLUMN id_pedido       SET NOT NULL;
ALTER TABLE detalle_pedido ALTER COLUMN id_producto     SET NOT NULL;
ALTER TABLE detalle_pedido ALTER COLUMN cantidad        SET NOT NULL;
ALTER TABLE detalle_pedido ALTER COLUMN precio_unitario SET NOT NULL;
ALTER TABLE detalle_pedido ADD CONSTRAINT pk_detalle_pedido PRIMARY KEY (id_pedido, id_producto);
ALTER TABLE detalle_pedido ADD CONSTRAINT ck_detalle_pedido_cantidad CHECK (cantidad > 0);
ALTER TABLE detalle_pedido ADD CONSTRAINT ck_detalle_pedido_precio CHECK (precio_unitario >= 0);
-- FK INTERNA
ALTER TABLE detalle_pedido ADD CONSTRAINT fk_detalle_pedido_pedido
    FOREIGN KEY (id_pedido) REFERENCES pedidos_venta (id_pedido);

-- ---------------------- pagos ----------------------------------------------
ALTER TABLE pagos ALTER COLUMN id_pedido  SET NOT NULL;
ALTER TABLE pagos ALTER COLUMN fecha_pago SET NOT NULL;
ALTER TABLE pagos ALTER COLUMN valor      SET NOT NULL;
ALTER TABLE pagos ALTER COLUMN medio_pago SET NOT NULL;
ALTER TABLE pagos ALTER COLUMN estado     SET NOT NULL;
ALTER TABLE pagos ADD CONSTRAINT pk_pagos PRIMARY KEY (id_pago);
ALTER TABLE pagos ADD CONSTRAINT ck_pagos_valor CHECK (valor > 0);
ALTER TABLE pagos ADD CONSTRAINT ck_pagos_medio CHECK (medio_pago IN ('Efectivo', 'Tarjeta Debito', 'Tarjeta Credito', 'Transferencia'));
ALTER TABLE pagos ADD CONSTRAINT ck_pagos_estado CHECK (estado IN ('Confirmado', 'Rechazado', 'Pendiente'));
-- FK INTERNA
ALTER TABLE pagos ADD CONSTRAINT fk_pagos_pedido
    FOREIGN KEY (id_pedido) REFERENCES pedidos_venta (id_pedido);

-- ---------------------- devoluciones ---------------------------------------
ALTER TABLE devoluciones ALTER COLUMN id_pedido       SET NOT NULL;
ALTER TABLE devoluciones ALTER COLUMN fecha_solicitud SET NOT NULL;
ALTER TABLE devoluciones ALTER COLUMN motivo          SET NOT NULL;
ALTER TABLE devoluciones ALTER COLUMN estado          SET NOT NULL;
ALTER TABLE devoluciones ADD CONSTRAINT pk_devoluciones PRIMARY KEY (id_devolucion);
ALTER TABLE devoluciones ADD CONSTRAINT ck_devoluciones_estado CHECK (estado IN ('Solicitada', 'Aprobada', 'Rechazada'));
-- FK INTERNA
ALTER TABLE devoluciones ADD CONSTRAINT fk_devoluciones_pedido
    FOREIGN KEY (id_pedido) REFERENCES pedidos_venta (id_pedido);

-- ---------------------- detalle_devolucion ---------------------------------
ALTER TABLE detalle_devolucion ALTER COLUMN id_devolucion      SET NOT NULL;
ALTER TABLE detalle_devolucion ALTER COLUMN id_producto        SET NOT NULL;
ALTER TABLE detalle_devolucion ALTER COLUMN cantidad           SET NOT NULL;
ALTER TABLE detalle_devolucion ALTER COLUMN condicion_producto SET NOT NULL;
ALTER TABLE detalle_devolucion ADD CONSTRAINT pk_detalle_devolucion PRIMARY KEY (id_devolucion, id_producto);
ALTER TABLE detalle_devolucion ADD CONSTRAINT ck_detalle_devolucion_cantidad CHECK (cantidad > 0);
ALTER TABLE detalle_devolucion ADD CONSTRAINT ck_detalle_devolucion_condicion CHECK (condicion_producto IN ('Buen Estado', 'Defectuoso', 'Dañado'));
-- FK INTERNA
ALTER TABLE detalle_devolucion ADD CONSTRAINT fk_detalle_devolucion_devolucion
    FOREIGN KEY (id_devolucion) REFERENCES devoluciones (id_devolucion);

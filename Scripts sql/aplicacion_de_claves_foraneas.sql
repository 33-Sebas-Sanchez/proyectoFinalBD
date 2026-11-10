-- ============================================================================
-- Proyecto Final - Bases de Datos
-- Claves foráneas (FOREIGN KEY) aplicadas con ALTER TABLE
-- ----------------------------------------------------------------------------
-- Convención: fk_<tabla>_<columna/referencia>
-- ============================================================================


-- ---------------------------------------------------------------------------
-- ESQUEMA: catalogo_terceros
-- ---------------------------------------------------------------------------

ALTER TABLE catalogo_terceros.almacenes
    ADD CONSTRAINT fk_almacenes_sede
    FOREIGN KEY (id_sede) REFERENCES catalogo_terceros.sedes (id_sede);

ALTER TABLE catalogo_terceros.productos
    ADD CONSTRAINT fk_productos_categoria
    FOREIGN KEY (id_categoria) REFERENCES catalogo_terceros.categorias (id_categoria);

ALTER TABLE catalogo_terceros.producto_proveedor
    ADD CONSTRAINT fk_producto_proveedor_producto
    FOREIGN KEY (id_producto) REFERENCES catalogo_terceros.productos (id_producto);

ALTER TABLE catalogo_terceros.producto_proveedor
    ADD CONSTRAINT fk_producto_proveedor_proveedor
    FOREIGN KEY (id_proveedor) REFERENCES catalogo_terceros.proveedores (id_proveedor);


-- ---------------------------------------------------------------------------
-- ESQUEMA: identidad_accesos
-- ---------------------------------------------------------------------------

ALTER TABLE identidad_accesos.empleados
    ADD CONSTRAINT fk_empleados_sede
    FOREIGN KEY (id_sede) REFERENCES catalogo_terceros.sedes (id_sede);

ALTER TABLE identidad_accesos.usuarios
    ADD CONSTRAINT fk_usuarios_empleado
    FOREIGN KEY (id_empleado) REFERENCES identidad_accesos.empleados (id_empleado);

ALTER TABLE identidad_accesos.auditoria_accesos
    ADD CONSTRAINT fk_auditoria_usuario
    FOREIGN KEY (id_usuario) REFERENCES identidad_accesos.usuarios (id_usuario);


-- ---------------------------------------------------------------------------
-- ESQUEMA: compras_abastecimiento
-- ---------------------------------------------------------------------------

ALTER TABLE compras_abastecimiento.ordenes_compra
    ADD CONSTRAINT fk_ordenes_compra_proveedor
    FOREIGN KEY (id_proveedor) REFERENCES catalogo_terceros.proveedores (id_proveedor);

ALTER TABLE compras_abastecimiento.ordenes_compra
    ADD CONSTRAINT fk_ordenes_compra_almacen
    FOREIGN KEY (id_almacen_destino) REFERENCES catalogo_terceros.almacenes (id_almacen);

ALTER TABLE compras_abastecimiento.ordenes_compra
    ADD CONSTRAINT fk_ordenes_compra_empleado
    FOREIGN KEY (id_empleado) REFERENCES identidad_accesos.empleados (id_empleado);

ALTER TABLE compras_abastecimiento.detalle_orden_compra
    ADD CONSTRAINT fk_detalle_oc_orden
    FOREIGN KEY (id_orden_compra) REFERENCES compras_abastecimiento.ordenes_compra (id_orden_compra);

ALTER TABLE compras_abastecimiento.detalle_orden_compra
    ADD CONSTRAINT fk_detalle_oc_producto
    FOREIGN KEY (id_producto) REFERENCES catalogo_terceros.productos (id_producto);

ALTER TABLE compras_abastecimiento.recepciones_compra
    ADD CONSTRAINT fk_recepciones_orden
    FOREIGN KEY (id_orden_compra) REFERENCES compras_abastecimiento.ordenes_compra (id_orden_compra);

ALTER TABLE compras_abastecimiento.detalle_recepcion
    ADD CONSTRAINT fk_detalle_recepcion_recepcion
    FOREIGN KEY (id_recepcion) REFERENCES compras_abastecimiento.recepciones_compra (id_recepcion);

ALTER TABLE compras_abastecimiento.detalle_recepcion
    ADD CONSTRAINT fk_detalle_recepcion_producto
    FOREIGN KEY (id_producto) REFERENCES catalogo_terceros.productos (id_producto);


-- ---------------------------------------------------------------------------
-- ESQUEMA: inventarios_transferencias
-- ---------------------------------------------------------------------------

ALTER TABLE inventarios_transferencias.inventarios
    ADD CONSTRAINT fk_inventarios_sede
    FOREIGN KEY (id_sede) REFERENCES catalogo_terceros.sedes (id_sede);

ALTER TABLE inventarios_transferencias.inventarios
    ADD CONSTRAINT fk_inventarios_almacen
    FOREIGN KEY (id_almacen) REFERENCES catalogo_terceros.almacenes (id_almacen);

ALTER TABLE inventarios_transferencias.inventarios
    ADD CONSTRAINT fk_inventarios_producto
    FOREIGN KEY (id_producto) REFERENCES catalogo_terceros.productos (id_producto);

ALTER TABLE inventarios_transferencias.transferencias
    ADD CONSTRAINT fk_transferencias_origen
    FOREIGN KEY (id_almacen_origen) REFERENCES catalogo_terceros.almacenes (id_almacen);

ALTER TABLE inventarios_transferencias.transferencias
    ADD CONSTRAINT fk_transferencias_destino
    FOREIGN KEY (id_almacen_destino) REFERENCES catalogo_terceros.almacenes (id_almacen);

ALTER TABLE inventarios_transferencias.detalle_transferencia
    ADD CONSTRAINT fk_detalle_transferencia_transferencia
    FOREIGN KEY (id_transferencia) REFERENCES inventarios_transferencias.transferencias (id_transferencia);

ALTER TABLE inventarios_transferencias.detalle_transferencia
    ADD CONSTRAINT fk_detalle_transferencia_producto
    FOREIGN KEY (id_producto) REFERENCES catalogo_terceros.productos (id_producto);


-- ---------------------------------------------------------------------------
-- ESQUEMA: ventas_pagos
-- ---------------------------------------------------------------------------
ALTER TABLE ventas_pagos.pedidos_venta
    ADD CONSTRAINT fk_pedidos_sede
    FOREIGN KEY (id_sede) REFERENCES catalogo_terceros.sedes (id_sede);

ALTER TABLE ventas_pagos.pedidos_venta
    ADD CONSTRAINT fk_pedidos_almacen
    FOREIGN KEY (id_almacen) REFERENCES catalogo_terceros.almacenes (id_almacen);

ALTER TABLE ventas_pagos.pedidos_venta
    ADD CONSTRAINT fk_pedidos_cliente
    FOREIGN KEY (id_cliente) REFERENCES catalogo_terceros.clientes (id_cliente);

ALTER TABLE ventas_pagos.pedidos_venta
    ADD CONSTRAINT fk_pedidos_empleado
    FOREIGN KEY (id_empleado) REFERENCES identidad_accesos.empleados (id_empleado);

ALTER TABLE ventas_pagos.detalle_pedido
    ADD CONSTRAINT fk_detalle_pedido_pedido
    FOREIGN KEY (id_pedido) REFERENCES ventas_pagos.pedidos_venta (id_pedido);

ALTER TABLE ventas_pagos.detalle_pedido
    ADD CONSTRAINT fk_detalle_pedido_producto
    FOREIGN KEY (id_producto) REFERENCES catalogo_terceros.productos (id_producto);

ALTER TABLE ventas_pagos.pagos
    ADD CONSTRAINT fk_pagos_pedido
    FOREIGN KEY (id_pedido) REFERENCES ventas_pagos.pedidos_venta (id_pedido);

ALTER TABLE ventas_pagos.devoluciones
    ADD CONSTRAINT fk_devoluciones_pedido
    FOREIGN KEY (id_pedido) REFERENCES ventas_pagos.pedidos_venta (id_pedido);

ALTER TABLE ventas_pagos.detalle_devolucion
    ADD CONSTRAINT fk_detalle_devolucion_devolucion
    FOREIGN KEY (id_devolucion) REFERENCES ventas_pagos.devoluciones (id_devolucion);

ALTER TABLE ventas_pagos.detalle_devolucion
    ADD CONSTRAINT fk_detalle_devolucion_producto
    FOREIGN KEY (id_producto) REFERENCES catalogo_terceros.productos (id_producto);

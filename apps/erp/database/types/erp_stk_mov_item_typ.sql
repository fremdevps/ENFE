-- =============================================================================
-- Tipo    : erp_stk_mov_item_typ
-- Desc    : Una línea de un movimiento de stock a registrar
--           (erp_stk_movimiento_api.registrar). Cantidades en la unidad base
--           del producto.
-- =============================================================================
create or replace type erp_stk_mov_item_typ force as object (
    deposito_id             number,
    producto_id             number,
    lote_id                 number,          -- obligatorio si el producto maneja lote o serie
    deposito_ubicacion_id   number,          -- null = sin ubicación
    cantidad                number,          -- positiva entra, negativa sale; 0 = línea que solo ajusta la reserva
    costo_unitario          number,          -- moneda funcional; null = al costo actual del saldo
    costo_unitario_reporte  number,          -- moneda de reporte; null = se convierte con la cotización de la fecha
    linea_costo             number,          -- toma el costo de esa línea anterior del mismo movimiento (traslados)
    reserva                 number,          -- variación de la reserva de la misma fila (negativa libera)
    origen_linea_id         number,          -- línea del documento de origen
    constructor function erp_stk_mov_item_typ (
        deposito_id             number,
        producto_id             number,
        cantidad                number,
        lote_id                 number default null,
        deposito_ubicacion_id   number default null,
        costo_unitario          number default null,
        costo_unitario_reporte  number default null,
        linea_costo             number default null,
        reserva                 number default null,
        origen_linea_id         number default null
    ) return self as result
);
/
create or replace type body erp_stk_mov_item_typ as
    constructor function erp_stk_mov_item_typ (
        deposito_id             number,
        producto_id             number,
        cantidad                number,
        lote_id                 number default null,
        deposito_ubicacion_id   number default null,
        costo_unitario          number default null,
        costo_unitario_reporte  number default null,
        linea_costo             number default null,
        reserva                 number default null,
        origen_linea_id         number default null
    ) return self as result is
    begin
        self.deposito_id            := deposito_id;
        self.producto_id            := producto_id;
        self.lote_id                := lote_id;
        self.deposito_ubicacion_id  := deposito_ubicacion_id;
        self.cantidad               := cantidad;
        self.costo_unitario         := costo_unitario;
        self.costo_unitario_reporte := costo_unitario_reporte;
        self.linea_costo            := linea_costo;
        self.reserva                := reserva;
        self.origen_linea_id        := origen_linea_id;
        return;
    end;
end;
/

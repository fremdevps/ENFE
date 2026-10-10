-- =============================================================================
-- Tipo    : erp_stk_tras_item_typ
-- Desc    : Una línea para las operaciones de traslado (crear, aprobar,
--           despachar, recibir, devolver). Cada operación usa solo los atributos
--           que le aplican.
-- =============================================================================
create or replace type erp_stk_tras_item_typ force as object (
    traslado_item_id        number,          -- ítem existente (aprobar, despachar, recibir, devolver)
    producto_id             number,          -- al crear
    lote_id                 number,          -- al crear
    cantidad                number,          -- solicitada / aprobada / despachada / recibida conforme / devuelta
    cantidad_averiada       number,          -- al recibir: con daños (a cuarentena)
    cantidad_faltante       number,          -- al recibir: faltante declarado
    cantidad_sobrante       number,          -- al recibir: sobrante informado
    deposito_ubicacion_id   number,          -- ubicación de retiro (crear) o de guardado (recibir)
    observacion             varchar2(400),
    constructor function erp_stk_tras_item_typ (
        cantidad                number,
        traslado_item_id        number   default null,
        producto_id             number   default null,
        lote_id                 number   default null,
        cantidad_averiada       number   default 0,
        cantidad_faltante       number   default 0,
        cantidad_sobrante       number   default 0,
        deposito_ubicacion_id   number   default null,
        observacion             varchar2 default null
    ) return self as result
);
/
create or replace type body erp_stk_tras_item_typ as
    constructor function erp_stk_tras_item_typ (
        cantidad                number,
        traslado_item_id        number   default null,
        producto_id             number   default null,
        lote_id                 number   default null,
        cantidad_averiada       number   default 0,
        cantidad_faltante       number   default 0,
        cantidad_sobrante       number   default 0,
        deposito_ubicacion_id   number   default null,
        observacion             varchar2 default null
    ) return self as result is
    begin
        self.traslado_item_id      := traslado_item_id;
        self.producto_id           := producto_id;
        self.lote_id               := lote_id;
        self.cantidad              := cantidad;
        self.cantidad_averiada     := coalesce(cantidad_averiada, 0);
        self.cantidad_faltante     := coalesce(cantidad_faltante, 0);
        self.cantidad_sobrante     := coalesce(cantidad_sobrante, 0);
        self.deposito_ubicacion_id := deposito_ubicacion_id;
        self.observacion           := observacion;
        return;
    end;
end;
/

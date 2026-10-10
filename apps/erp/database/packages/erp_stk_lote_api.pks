create or replace package erp_stk_lote_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_stk_lote_api   (capa api)
-- Desc    : Lotes y números de serie. El lote es siempre una entidad (nunca un
--           texto en el documento): compras lo crea al recibir y los
--           movimientos lo referencian por lote_id. Requiere ERP_STK_LOTE_GESTIONAR.
-- =============================================================================

    -- Crea el lote o la serie del producto. Si el producto lleva vencimiento y no
    -- se indica, se calcula con la elaboración más su vida útil.
    procedure crear (
        i_producto_id        in  erp_stk_lote.producto_id%type,
        i_codigo             in  erp_stk_lote.codigo%type,
        i_fecha_elaboracion  in  erp_stk_lote.fecha_elaboracion%type default null,
        i_fecha_vencimiento  in  erp_stk_lote.fecha_vencimiento%type default null,
        o_lote_id            out erp_stk_lote.lote_id%type
    );

    -- Corrige fechas o cambia el estado (A activo, B bloqueado: no sale, I inactivo).
    procedure modificar (
        i_lote_id            in erp_stk_lote.lote_id%type,
        i_fecha_elaboracion  in erp_stk_lote.fecha_elaboracion%type,
        i_fecha_vencimiento  in erp_stk_lote.fecha_vencimiento%type,
        i_estado             in erp_stk_lote.estado%type
    );

    -- Null si no existe.
    function obtener_id (
        i_producto_id  in erp_stk_lote.producto_id%type,
        i_codigo       in erp_stk_lote.codigo%type
    ) return number;

end erp_stk_lote_api;
/

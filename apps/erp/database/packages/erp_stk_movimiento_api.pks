create or replace package erp_stk_movimiento_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_stk_movimiento_api   (capa api)
-- Desc    : Fachada pública del motor de stock para APEX / REST / jobs:
--           movimientos, ajustes, anulación por reverso, reservas y consultas
--           de saldo. Verifica permisos ERP_STK_* (solo si hay usuario de
--           sesión). Los paquetes reg de otros módulos (compras, ventas) usan
--           erp_stk_movimiento_reg directamente, dentro de su propia transacción.
--           Diseño y ejemplos: docs/diseno-stk-inventario.md.
-- =============================================================================

    -- Movimiento genérico. Cantidad positiva entra, negativa sale.
    procedure registrar (
        i_empresa_id       in  number,
        i_tipo_movimiento  in  varchar2,
        i_fecha            in  date,
        i_items            in  erp_stk_mov_item_tab,
        i_origen_modulo    in  varchar2 default 'STK',
        i_origen_tabla     in  varchar2 default null,
        i_origen_id        in  number   default null,
        i_motivo           in  varchar2 default null,
        i_observacion      in  varchar2 default null,
        o_movimiento_id    out number
    );

    -- Ajuste de entrada de un producto (cantidad positiva). Sin costo entra al
    -- costo actual del saldo.
    procedure crear_ajuste_entrada (
        i_empresa_id              in  number,
        i_deposito_id             in  number,
        i_producto_id             in  number,
        i_cantidad                in  number,
        i_motivo                  in  varchar2,
        i_costo_unitario          in  number   default null,
        i_costo_unitario_reporte  in  number   default null,
        i_lote_id                 in  number   default null,
        i_deposito_ubicacion_id   in  number   default null,
        i_fecha                   in  date     default trunc(current_date),
        i_observacion             in  varchar2 default null,
        o_movimiento_id           out number
    );

    -- Ajuste de salida de un producto (cantidad positiva; sale al costo del saldo).
    procedure crear_ajuste_salida (
        i_empresa_id             in  number,
        i_deposito_id            in  number,
        i_producto_id            in  number,
        i_cantidad               in  number,
        i_motivo                 in  varchar2,
        i_lote_id                in  number   default null,
        i_deposito_ubicacion_id  in  number   default null,
        i_fecha                  in  date     default trunc(current_date),
        i_observacion            in  varchar2 default null,
        o_movimiento_id          out number
    );

    -- Anula un movimiento manual con un movimiento de reverso (nunca se borra).
    -- Los movimientos generados por un documento se anulan desde ese documento.
    procedure anular (
        i_movimiento_id  in  number,
        i_motivo         in  varchar2,
        i_fecha          in  date default trunc(current_date),
        o_movimiento_id  out number
    );

    procedure reservar (
        i_empresa_id             in number,
        i_deposito_id            in number,
        i_producto_id            in number,
        i_cantidad               in number,
        i_lote_id                in number default null,
        i_deposito_ubicacion_id  in number default null
    );

    procedure liberar_reserva (
        i_empresa_id             in number,
        i_deposito_id            in number,
        i_producto_id            in number,
        i_cantidad               in number,
        i_lote_id                in number default null,
        i_deposito_ubicacion_id  in number default null
    );

    -- Disponible = existencia - reservado (sin cuarentena ni tránsito).
    function obtener_disponible (
        i_empresa_id             in number,
        i_deposito_id            in number,
        i_producto_id            in number,
        i_lote_id                in number default null,
        i_deposito_ubicacion_id  in number default null
    ) return number;

    -- Existencia física (incluye reservado y cuarentena). i_deposito_id null = toda la empresa.
    function obtener_saldo (
        i_empresa_id             in number,
        i_producto_id            in number,
        i_deposito_id            in number default null,
        i_lote_id                in number default null,
        i_deposito_ubicacion_id  in number default null
    ) return number;

    -- Costo unitario del saldo (ponderado por las filas con existencia).
    -- i_es_reporte = 'S' lo devuelve en moneda de reporte.
    function obtener_costo (
        i_empresa_id   in number,
        i_producto_id  in number,
        i_deposito_id  in number   default null,
        i_lote_id      in number   default null,
        i_es_reporte   in varchar2 default 'N'
    ) return number;

end erp_stk_movimiento_api;
/

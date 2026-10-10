create or replace package erp_stk_movimiento_reg
    authid definer
as
-- =============================================================================
-- Paquete : erp_stk_movimiento_reg   (capa reg)
-- Desc    : Motor de movimientos de stock. Valida, bloquea las filas de saldo
--           en orden, calcula el costo y graba movimiento + saldo en la misma
--           transacción. Lo usan erp_stk_movimiento_api, los traslados y los
--           paquetes reg de otros módulos (compras, ventas). Nunca hace COMMIT.
--
--   Costo del saldo (por fila: depósito + producto + lote + ubicación):
--     - entrada con costo  : promedio ponderado (P) o último costo (U), según
--                            el producto o el parámetro ERP_STK_METODO_COSTO.
--     - entrada sin costo  : entra al costo actual del saldo (no lo cambia).
--     - salida sin costo   : sale al costo actual del saldo (no lo cambia).
--     - salida con costo   : reverso de una entrada o salida de mercadería
--                            identificada: retira ese valor y recalcula el promedio.
--   Control de saldo: si el depósito tiene debe_controlar_stock = 'S' (o es de
--   tránsito) ninguna salida puede dejar el disponible (cantidad - reservado)
--   por debajo de cero.
-- =============================================================================

    c_err_stock_insuficiente  constant pls_integer := -20162;
    c_err_lote_invalido       constant pls_integer := -20163;
    c_err_lote_vencido        constant pls_integer := -20164;
    c_err_deposito_invalido   constant pls_integer := -20165;
    c_err_producto_invalido   constant pls_integer := -20166;
    c_err_no_reversable       constant pls_integer := -20167;
    c_err_reserva_invalida    constant pls_integer := -20168;
    c_err_ubicacion_invalida  constant pls_integer := -20169;

    -- Registra un movimiento. i_tipo_movimiento es el código del catálogo
    -- erp_stk_tipo_movimiento. Valida el período STK abierto en i_fecha.
    procedure generar (
        i_empresa_id       in  erp_stk_movimiento.empresa_id%type,
        i_tipo_movimiento  in  erp_stk_tipo_movimiento.codigo%type,
        i_fecha            in  erp_stk_movimiento.fecha_movimiento%type,
        i_items            in  erp_stk_mov_item_tab,
        i_origen_modulo    in  erp_stk_movimiento.origen_modulo%type default 'STK',
        i_origen_tabla     in  erp_stk_movimiento.origen_tabla%type  default null,
        i_origen_id        in  erp_stk_movimiento.origen_id%type     default null,
        i_motivo           in  erp_stk_movimiento.motivo%type        default null,
        i_observacion      in  erp_stk_movimiento.observacion%type   default null,
        o_movimiento_id    out erp_stk_movimiento.movimiento_id%type
    );

    -- Anula un movimiento con otro de signo contrario y los mismos costos.
    -- El original queda en estado R; un reverso no se puede reversar.
    procedure generar_reverso (
        i_movimiento_id  in  erp_stk_movimiento.movimiento_id%type,
        i_fecha          in  erp_stk_movimiento.fecha_movimiento%type,
        i_motivo         in  erp_stk_movimiento.motivo%type,
        o_movimiento_id  out erp_stk_movimiento.movimiento_id%type
    );

    -- Reserva (cantidad positiva) o libera (negativa) stock, sin movimiento.
    -- Usa de cada ítem: depósito, producto, lote, ubicación y reserva.
    procedure aplicar_reserva (
        i_empresa_id  in erp_stk_saldo.empresa_id%type,
        i_items       in erp_stk_mov_item_tab
    );

    -- Disponible = cantidad - reservado, sin cuarentena ni depósitos de tránsito.
    -- i_lote_id / i_deposito_ubicacion_id null = todos.
    function calcular_disponible (
        i_empresa_id             in erp_stk_saldo.empresa_id%type,
        i_deposito_id            in erp_stk_saldo.deposito_id%type,
        i_producto_id            in erp_stk_saldo.producto_id%type,
        i_lote_id                in erp_stk_saldo.lote_id%type               default null,
        i_deposito_ubicacion_id  in erp_stk_saldo.deposito_ubicacion_id%type default null
    ) return number;

    -- 'P' promedio ponderado o 'U' último costo: el del producto o, si no lo
    -- define, el parámetro ERP_STK_METODO_COSTO de la empresa (por defecto P).
    function calcular_metodo_costo (
        i_empresa_id    in number,
        i_metodo_costo  in erp_stk_producto.metodo_costo%type
    ) return varchar2;

end erp_stk_movimiento_reg;
/

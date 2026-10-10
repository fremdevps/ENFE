create or replace package erp_stk_saldo_ctr
    authid definer
    accessible by (package erp_stk_movimiento_reg)
as
-- =============================================================================
-- Paquete : erp_stk_saldo_ctr   (capa ctr)
-- Tabla   : erp_stk_saldo
-- Desc    : Único punto que escribe el saldo de stock. El motor de movimientos
--           bloquea primero todas las filas que va a tocar (siempre en el mismo
--           orden: depósito, producto, lote, ubicación) y después las actualiza:
--           dos transacciones nunca se esperan en cruz (sin interbloqueos).
-- =============================================================================

    -- Filas de saldo indexadas por su clave ordenable (obtener_clave).
    type t_saldo_mapa is table of erp_stk_saldo%rowtype index by varchar2(80);

    function obtener_clave (
        i_deposito_id            in erp_stk_saldo.deposito_id%type,
        i_producto_id            in erp_stk_saldo.producto_id%type,
        i_lote_id                in erp_stk_saldo.lote_id%type,
        i_deposito_ubicacion_id  in erp_stk_saldo.deposito_ubicacion_id%type
    ) return varchar2;

    -- Bloquea (select … for update) cada fila del mapa en orden de clave y
    -- devuelve sus valores actuales. Si la fila no existe la crea en cero con
    -- los datos del mapa (empresa, depósito, producto, lote, ubicación, es_disponible).
    procedure bloquear (
        io_saldos  in out nocopy t_saldo_mapa
    );

    -- Graba cantidad, reservado, costos y fecha de las filas del mapa (ya bloqueadas).
    procedure actualizar (
        i_saldos  in t_saldo_mapa
    );

end erp_stk_saldo_ctr;
/

create or replace package erp_stk_producto_ctr
    authid definer
    accessible by (package erp_stk_producto_reg, package erp_stk_producto_api)
as
-- =============================================================================
-- Paquete : erp_stk_producto_ctr   (capa ctr)
-- Tabla   : erp_stk_producto
-- =============================================================================

    procedure insertar (
        i_producto     in  erp_stk_producto%rowtype,
        o_producto_id  out erp_stk_producto.producto_id%type
    );

    procedure actualizar (
        i_producto  in erp_stk_producto%rowtype
    );

    -- Registro vacío (producto_id null) si no existe.
    function obtener (
        i_producto_id  in erp_stk_producto.producto_id%type
    ) return erp_stk_producto%rowtype;

end erp_stk_producto_ctr;
/

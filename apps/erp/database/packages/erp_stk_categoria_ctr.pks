create or replace package erp_stk_categoria_ctr
    authid definer
    accessible by (package erp_stk_categoria_api)
as
-- =============================================================================
-- Paquete : erp_stk_categoria_ctr   (capa ctr)
-- Tabla   : erp_stk_categoria
-- =============================================================================

    procedure insertar (
        i_categoria     in  erp_stk_categoria%rowtype,
        o_categoria_id  out erp_stk_categoria.categoria_id%type
    );

    procedure actualizar (
        i_categoria  in erp_stk_categoria%rowtype
    );

    -- Registro vacío (categoria_id null) si no existe.
    function obtener (
        i_categoria_id  in erp_stk_categoria.categoria_id%type
    ) return erp_stk_categoria%rowtype;

end erp_stk_categoria_ctr;
/

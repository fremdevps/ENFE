create or replace package erp_stk_producto_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_stk_producto_api   (capa api)
-- Desc    : Alta y modificación de productos para APEX / REST, búsqueda por
--           código y conversión de unidades. Requiere ERP_STK_PRODUCTO_GESTIONAR.
--           El producto se recibe como registro (%rowtype): el maestro tiene
--           muchos campos opcionales y así una columna nueva no cambia la firma.
--           Los códigos alternativos, equivalentes, datos por depósito y por
--           proveedor y los componentes de un kit son catálogos simples (sus
--           reglas son constraints): se mantienen con el guardado de APEX.
-- =============================================================================

    procedure crear (
        i_producto     in  erp_stk_producto%rowtype,
        o_producto_id  out erp_stk_producto.producto_id%type
    );

    -- i_producto.producto_id indica el producto; se reemplazan todos sus datos.
    procedure modificar (
        i_producto  in erp_stk_producto%rowtype
    );

    -- Para validar en pantalla los atributos antes de guardar.
    procedure validar_atributos (
        i_categoria_id  in number,
        i_atributos     in varchar2
    );

    -- Producto por su código interno o por cualquier código alternativo activo
    -- (barras, proveedor, externo). Null si no existe o si el código es ambiguo.
    function obtener_id (
        i_empresa_id  in number,
        i_codigo      in varchar2
    ) return number;

    -- Cantidad en unidad base (la unidad en que se lleva el stock).
    function obtener_cantidad_base (
        i_producto_id  in number,
        i_unidad_id    in number,
        i_cantidad     in number
    ) return number;

end erp_stk_producto_api;
/

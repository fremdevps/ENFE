create or replace package erp_stk_producto_reg
    authid definer
as
-- =============================================================================
-- Paquete : erp_stk_producto_reg   (capa reg)
-- Desc    : Reglas del maestro de productos: normalización, funcionalidades
--           activas de la empresa (lote, serie, vencimiento), atributos por
--           rubro (JSON validado contra la definición de la categoría y de sus
--           categorías superiores) y conversión entre unidades.
--
--   Definición de atributos (erp_stk_categoria.atributos_def), un arreglo:
--     [{"codigo":"talle","nombre":"Talle","tipo":"T","requerido":"S","valores":["S","M","L"]},
--      {"codigo":"potencia_hp","nombre":"Potencia (HP)","tipo":"N"}]
--   tipo: T texto, N número, F fecha (AAAA-MM-DD), S sí/no ("S"/"N").
--   Atributos del producto (erp_stk_producto.atributos): {"talle":"M","potencia_hp":150}
-- =============================================================================

    c_err_conversion  constant pls_integer := -20177;
    c_err_atributos   constant pls_integer := -20178;

    -- Valida el formato de una definición de atributos.
    procedure validar_definicion_atributos (
        i_atributos_def  in erp_stk_categoria.atributos_def%type
    );

    -- Valida los atributos de un producto contra la definición de su categoría.
    procedure validar_atributos (
        i_categoria_id  in erp_stk_producto.categoria_id%type,
        i_atributos     in erp_stk_producto.atributos%type
    );

    -- Normaliza y valida el producto antes de insertar (producto_id null) o actualizar.
    procedure validar (
        io_producto  in out nocopy erp_stk_producto%rowtype
    );

    -- Convierte una cantidad expresada en i_unidad_id a la unidad base del producto.
    function calcular_cantidad_base (
        i_producto_id  in erp_stk_producto.producto_id%type,
        i_unidad_id    in erp_stk_unidad.unidad_id%type,
        i_cantidad     in number
    ) return number;

end erp_stk_producto_reg;
/

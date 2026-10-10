create or replace package erp_stk_categoria_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_stk_categoria_api   (capa api)
-- Desc    : Categorías de producto en árbol. Valida que el árbol no tenga
--           ciclos y el formato de la definición de atributos. La línea de
--           negocio y el grupo contable se heredan de la categoría superior
--           cuando la propia no los define. Requiere ERP_STK_CATALOGO_GESTIONAR.
-- =============================================================================

    procedure crear (
        i_empresa_id          in  erp_stk_categoria.empresa_id%type,
        i_codigo              in  erp_stk_categoria.codigo%type,
        i_nombre              in  erp_stk_categoria.nombre%type,
        i_categoria_id_padre  in  erp_stk_categoria.categoria_id_padre%type default null,
        i_linea_negocio       in  erp_stk_categoria.linea_negocio%type      default null,
        i_grupo_contable      in  erp_stk_categoria.grupo_contable%type     default null,
        i_atributos_def       in  erp_stk_categoria.atributos_def%type      default null,
        i_estado              in  erp_stk_categoria.estado%type             default 'A',
        o_categoria_id        out erp_stk_categoria.categoria_id%type
    );

    procedure modificar (
        i_categoria_id        in erp_stk_categoria.categoria_id%type,
        i_codigo              in erp_stk_categoria.codigo%type,
        i_nombre              in erp_stk_categoria.nombre%type,
        i_categoria_id_padre  in erp_stk_categoria.categoria_id_padre%type,
        i_linea_negocio       in erp_stk_categoria.linea_negocio%type,
        i_grupo_contable      in erp_stk_categoria.grupo_contable%type,
        i_atributos_def       in erp_stk_categoria.atributos_def%type,
        i_estado              in erp_stk_categoria.estado%type
    );

    -- Línea de negocio propia o heredada de la categoría superior más cercana.
    function obtener_linea_negocio (
        i_categoria_id  in erp_stk_categoria.categoria_id%type
    ) return varchar2;

    -- Grupo contable propio o heredado de la categoría superior más cercana.
    function obtener_grupo_contable (
        i_categoria_id  in erp_stk_categoria.categoria_id%type
    ) return varchar2;

end erp_stk_categoria_api;
/

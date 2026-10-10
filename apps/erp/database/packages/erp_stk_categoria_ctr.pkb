create or replace package body erp_stk_categoria_ctr
as

    procedure insertar (
        i_categoria     in  erp_stk_categoria%rowtype,
        o_categoria_id  out erp_stk_categoria.categoria_id%type
    ) is
    begin
        insert into erp_stk_categoria (
            empresa_id, categoria_id_padre, codigo, nombre, linea_negocio, grupo_contable, atributos_def, estado)
        values (
            i_categoria.empresa_id, i_categoria.categoria_id_padre, i_categoria.codigo, i_categoria.nombre,
            i_categoria.linea_negocio, i_categoria.grupo_contable, i_categoria.atributos_def, i_categoria.estado)
        returning categoria_id into o_categoria_id;
    end insertar;

    procedure actualizar (
        i_categoria  in erp_stk_categoria%rowtype
    ) is
    begin
        update erp_stk_categoria
           set categoria_id_padre = i_categoria.categoria_id_padre,
               codigo             = i_categoria.codigo,
               nombre             = i_categoria.nombre,
               linea_negocio      = i_categoria.linea_negocio,
               grupo_contable     = i_categoria.grupo_contable,
               atributos_def      = i_categoria.atributos_def,
               estado             = i_categoria.estado
         where categoria_id = i_categoria.categoria_id;
    end actualizar;

    function obtener (
        i_categoria_id  in erp_stk_categoria.categoria_id%type
    ) return erp_stk_categoria%rowtype is
        r_categoria  erp_stk_categoria%rowtype;
    begin
        select * into r_categoria from erp_stk_categoria where categoria_id = i_categoria_id;
        return r_categoria;
    exception
        when no_data_found then
            return r_categoria;
    end obtener;

end erp_stk_categoria_ctr;
/

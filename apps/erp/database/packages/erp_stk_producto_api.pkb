create or replace package body erp_stk_producto_api
as

    procedure crear (
        i_producto     in  erp_stk_producto%rowtype,
        o_producto_id  out erp_stk_producto.producto_id%type
    ) is
        r_producto  erp_stk_producto%rowtype := i_producto;
    begin
        erp_stk_comun_utl.validar_permiso(i_permiso => 'ERP_STK_PRODUCTO_GESTIONAR', i_empresa_id => i_producto.empresa_id);
        r_producto.producto_id := null;
        erp_stk_producto_reg.validar(io_producto => r_producto);
        erp_stk_producto_ctr.insertar(i_producto => r_producto, o_producto_id => o_producto_id);
    end crear;

    procedure modificar (
        i_producto  in erp_stk_producto%rowtype
    ) is
        r_producto  erp_stk_producto%rowtype := i_producto;
    begin
        erp_stk_comun_utl.validar_permiso(i_permiso => 'ERP_STK_PRODUCTO_GESTIONAR', i_empresa_id => i_producto.empresa_id);
        if r_producto.producto_id is null then
            raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'Indique el producto a modificar.');
        end if;
        erp_stk_producto_reg.validar(io_producto => r_producto);
        erp_stk_producto_ctr.actualizar(i_producto => r_producto);
    end modificar;

    procedure validar_atributos (
        i_categoria_id  in number,
        i_atributos     in varchar2
    ) is
    begin
        erp_stk_producto_reg.validar_atributos(i_categoria_id => i_categoria_id, i_atributos => i_atributos);
    end validar_atributos;

    function obtener_id (
        i_empresa_id  in number,
        i_codigo      in varchar2
    ) return number is
        v_producto_id  number;
    begin
        begin
            select producto_id
              into v_producto_id
              from erp_stk_producto
             where empresa_id = i_empresa_id
               and codigo     = upper(trim(i_codigo));
            return v_producto_id;
        exception
            when no_data_found then
                null;
        end;
        select min(producto_id)
          into v_producto_id
          from erp_stk_producto_codigo
         where empresa_id = i_empresa_id
           and valor      = trim(i_codigo)
           and estado     = 'A'
        having count(distinct producto_id) = 1;
        return v_producto_id;
    exception
        when no_data_found then
            return null;
    end obtener_id;

    function obtener_cantidad_base (
        i_producto_id  in number,
        i_unidad_id    in number,
        i_cantidad     in number
    ) return number is
    begin
        return erp_stk_producto_reg.calcular_cantidad_base(
                   i_producto_id => i_producto_id,
                   i_unidad_id   => i_unidad_id,
                   i_cantidad    => i_cantidad);
    end obtener_cantidad_base;

end erp_stk_producto_api;
/

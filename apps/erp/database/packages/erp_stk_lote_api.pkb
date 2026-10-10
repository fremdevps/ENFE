create or replace package body erp_stk_lote_api
as

    type t_producto is record (
        empresa_id         erp_stk_producto.empresa_id%type,
        codigo             erp_stk_producto.codigo%type,
        tiene_lote         erp_stk_producto.tiene_lote%type,
        tiene_serie        erp_stk_producto.tiene_serie%type,
        tiene_vencimiento  erp_stk_producto.tiene_vencimiento%type,
        dias_vida_util     erp_stk_producto.dias_vida_util%type
    );

    function obtener_producto (
        i_producto_id  in number
    ) return t_producto is
        r_producto  t_producto;
    begin
        select empresa_id, codigo, tiene_lote, tiene_serie, tiene_vencimiento, dias_vida_util
          into r_producto
          from erp_stk_producto
         where producto_id = i_producto_id;
        return r_producto;
    exception
        when no_data_found then
            raise_application_error(erp_stk_comun_utl.c_err_no_existe, 'El producto indicado no existe.');
    end obtener_producto;

    procedure validar_vencimiento (
        i_producto  in t_producto,
        i_lote      in erp_stk_lote%rowtype
    ) is
    begin
        if i_producto.tiene_vencimiento = 'S' and i_lote.fecha_vencimiento is null then
            raise_application_error(erp_stk_movimiento_reg.c_err_lote_invalido,
                'El producto ' || i_producto.codigo || ' exige la fecha de vencimiento del lote.');
        end if;
    end validar_vencimiento;

    procedure crear (
        i_producto_id        in  erp_stk_lote.producto_id%type,
        i_codigo             in  erp_stk_lote.codigo%type,
        i_fecha_elaboracion  in  erp_stk_lote.fecha_elaboracion%type default null,
        i_fecha_vencimiento  in  erp_stk_lote.fecha_vencimiento%type default null,
        o_lote_id            out erp_stk_lote.lote_id%type
    ) is
        r_producto  t_producto := obtener_producto(i_producto_id => i_producto_id);
        r_lote      erp_stk_lote%rowtype;
    begin
        erp_stk_comun_utl.validar_permiso(i_permiso => 'ERP_STK_LOTE_GESTIONAR', i_empresa_id => r_producto.empresa_id);
        if r_producto.tiene_lote = 'N' and r_producto.tiene_serie = 'N' then
            raise_application_error(erp_stk_movimiento_reg.c_err_lote_invalido,
                'El producto ' || r_producto.codigo || ' no maneja lote ni serie.');
        end if;
        if trim(i_codigo) is null then
            raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'Indique el número de lote o de serie.');
        end if;
        r_lote.empresa_id        := r_producto.empresa_id;
        r_lote.producto_id       := i_producto_id;
        r_lote.codigo            := upper(trim(i_codigo));
        r_lote.tipo              := case when r_producto.tiene_serie = 'S' then 'S' else 'L' end;
        r_lote.fecha_elaboracion := trunc(i_fecha_elaboracion);
        r_lote.fecha_vencimiento := trunc(coalesce(i_fecha_vencimiento, i_fecha_elaboracion + r_producto.dias_vida_util));
        r_lote.estado            := 'A';
        validar_vencimiento(i_producto => r_producto, i_lote => r_lote);
        erp_stk_lote_ctr.insertar(i_lote => r_lote, o_lote_id => o_lote_id);
    end crear;

    procedure modificar (
        i_lote_id            in erp_stk_lote.lote_id%type,
        i_fecha_elaboracion  in erp_stk_lote.fecha_elaboracion%type,
        i_fecha_vencimiento  in erp_stk_lote.fecha_vencimiento%type,
        i_estado             in erp_stk_lote.estado%type
    ) is
        r_lote      erp_stk_lote%rowtype := erp_stk_lote_ctr.obtener(i_lote_id => i_lote_id);
        r_producto  t_producto;
    begin
        if r_lote.lote_id is null then
            raise_application_error(erp_stk_comun_utl.c_err_no_existe, 'El lote indicado no existe.');
        end if;
        erp_stk_comun_utl.validar_permiso(i_permiso => 'ERP_STK_LOTE_GESTIONAR', i_empresa_id => r_lote.empresa_id);
        r_producto := obtener_producto(i_producto_id => r_lote.producto_id);
        r_lote.fecha_elaboracion := trunc(i_fecha_elaboracion);
        r_lote.fecha_vencimiento := trunc(i_fecha_vencimiento);
        r_lote.estado            := coalesce(i_estado, r_lote.estado);
        validar_vencimiento(i_producto => r_producto, i_lote => r_lote);
        erp_stk_lote_ctr.actualizar(i_lote => r_lote);
    end modificar;

    function obtener_id (
        i_producto_id  in erp_stk_lote.producto_id%type,
        i_codigo       in erp_stk_lote.codigo%type
    ) return number is
        v_lote_id  number;
    begin
        select lote_id
          into v_lote_id
          from erp_stk_lote
         where producto_id = i_producto_id
           and codigo      = upper(trim(i_codigo));
        return v_lote_id;
    exception
        when no_data_found then
            return null;
    end obtener_id;

end erp_stk_lote_api;
/

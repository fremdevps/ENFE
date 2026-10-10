create or replace package body erp_stk_categoria_api
as

    procedure validar (
        i_categoria  in erp_stk_categoria%rowtype
    ) is
        r_padre     erp_stk_categoria%rowtype;
        v_cantidad  pls_integer;
    begin
        if i_categoria.codigo is null or i_categoria.nombre is null then
            raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'La categoría necesita código y nombre.');
        end if;
        if i_categoria.categoria_id_padre is not null then
            r_padre := erp_stk_categoria_ctr.obtener(i_categoria_id => i_categoria.categoria_id_padre);
            if r_padre.categoria_id is null or r_padre.empresa_id <> i_categoria.empresa_id then
                raise_application_error(erp_stk_comun_utl.c_err_dato_invalido,
                    'La categoría superior no existe o es de otra empresa.');
            end if;
            if i_categoria.categoria_id is not null then
                -- La superior no puede ser la propia categoría ni una de sus descendientes
                select count(*)
                  into v_cantidad
                  from erp_stk_categoria
                 where categoria_id = i_categoria.categoria_id_padre
                 start with categoria_id = i_categoria.categoria_id
               connect by nocycle prior categoria_id = categoria_id_padre;
                if v_cantidad > 0 then
                    raise_application_error(erp_stk_comun_utl.c_err_dato_invalido,
                        'La categoría superior no puede ser la misma categoría ni una que dependa de ella.');
                end if;
            end if;
        end if;
        erp_stk_producto_reg.validar_definicion_atributos(i_atributos_def => i_categoria.atributos_def);
    end validar;

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
    ) is
        r_categoria  erp_stk_categoria%rowtype;
    begin
        erp_stk_comun_utl.validar_permiso(i_permiso => 'ERP_STK_CATALOGO_GESTIONAR', i_empresa_id => i_empresa_id);
        r_categoria.empresa_id         := i_empresa_id;
        r_categoria.codigo             := upper(trim(i_codigo));
        r_categoria.nombre             := trim(i_nombre);
        r_categoria.categoria_id_padre := i_categoria_id_padre;
        r_categoria.linea_negocio      := upper(trim(i_linea_negocio));
        r_categoria.grupo_contable     := upper(trim(i_grupo_contable));
        r_categoria.atributos_def      := i_atributos_def;
        r_categoria.estado             := coalesce(i_estado, 'A');
        validar(i_categoria => r_categoria);
        erp_stk_categoria_ctr.insertar(i_categoria => r_categoria, o_categoria_id => o_categoria_id);
    end crear;

    procedure modificar (
        i_categoria_id        in erp_stk_categoria.categoria_id%type,
        i_codigo              in erp_stk_categoria.codigo%type,
        i_nombre              in erp_stk_categoria.nombre%type,
        i_categoria_id_padre  in erp_stk_categoria.categoria_id_padre%type,
        i_linea_negocio       in erp_stk_categoria.linea_negocio%type,
        i_grupo_contable      in erp_stk_categoria.grupo_contable%type,
        i_atributos_def       in erp_stk_categoria.atributos_def%type,
        i_estado              in erp_stk_categoria.estado%type
    ) is
        r_categoria  erp_stk_categoria%rowtype;
    begin
        r_categoria := erp_stk_categoria_ctr.obtener(i_categoria_id => i_categoria_id);
        if r_categoria.categoria_id is null then
            raise_application_error(erp_stk_comun_utl.c_err_no_existe, 'La categoría indicada no existe.');
        end if;
        erp_stk_comun_utl.validar_permiso(i_permiso => 'ERP_STK_CATALOGO_GESTIONAR', i_empresa_id => r_categoria.empresa_id);
        r_categoria.codigo             := upper(trim(i_codigo));
        r_categoria.nombre             := trim(i_nombre);
        r_categoria.categoria_id_padre := i_categoria_id_padre;
        r_categoria.linea_negocio      := upper(trim(i_linea_negocio));
        r_categoria.grupo_contable     := upper(trim(i_grupo_contable));
        r_categoria.atributos_def      := i_atributos_def;
        r_categoria.estado             := coalesce(i_estado, 'A');
        validar(i_categoria => r_categoria);
        erp_stk_categoria_ctr.actualizar(i_categoria => r_categoria);
    end modificar;

    function obtener_linea_negocio (
        i_categoria_id  in erp_stk_categoria.categoria_id%type
    ) return varchar2 is
        v_valor  erp_stk_categoria.linea_negocio%type;
    begin
        select max(linea_negocio) keep (dense_rank first order by level)
          into v_valor
          from erp_stk_categoria
         where linea_negocio is not null
         start with categoria_id = i_categoria_id
       connect by nocycle prior categoria_id_padre = categoria_id;
        return v_valor;
    end obtener_linea_negocio;

    function obtener_grupo_contable (
        i_categoria_id  in erp_stk_categoria.categoria_id%type
    ) return varchar2 is
        v_valor  erp_stk_categoria.grupo_contable%type;
    begin
        select max(grupo_contable) keep (dense_rank first order by level)
          into v_valor
          from erp_stk_categoria
         where grupo_contable is not null
         start with categoria_id = i_categoria_id
       connect by nocycle prior categoria_id_padre = categoria_id;
        return v_valor;
    end obtener_grupo_contable;

end erp_stk_categoria_api;
/

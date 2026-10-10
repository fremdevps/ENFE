create or replace package body erp_stk_producto_reg
as

    type t_definicion is record (
        nombre     varchar2(200),
        tipo       varchar2(1),
        requerido  varchar2(1),
        valores    json_array_t
    );
    type t_definicion_mapa is table of t_definicion index by varchar2(100);

    procedure lanzar_atributos (
        i_mensaje  in varchar2
    ) is
    begin
        raise_application_error(c_err_atributos, i_mensaje);
    end lanzar_atributos;

    -- Agrega al mapa los atributos de una definición (sin pisar los ya cargados).
    procedure agregar_definicion (
        i_atributos_def  in varchar2,
        io_definiciones  in out nocopy t_definicion_mapa
    ) is
        v_arreglo   json_array_t;
        v_objeto    json_object_t;
        v_codigo    varchar2(100);
        r_def       t_definicion;
    begin
        if i_atributos_def is null then
            return;
        end if;
        begin
            v_arreglo := json_array_t.parse(i_atributos_def);
        exception
            when others then
                lanzar_atributos(i_mensaje => 'La definición de atributos debe ser un arreglo JSON.');
        end;
        for i in 0 .. v_arreglo.get_size - 1 loop
            if not v_arreglo.get(i).is_object then
                lanzar_atributos(i_mensaje => 'Cada atributo de la definición debe ser un objeto con codigo, nombre y tipo.');
            end if;
            v_objeto := treat(v_arreglo.get(i) as json_object_t);
            v_codigo := v_objeto.get_string('codigo');
            r_def.nombre    := coalesce(v_objeto.get_string('nombre'), v_codigo);
            r_def.tipo      := upper(coalesce(v_objeto.get_string('tipo'), 'T'));
            r_def.requerido := upper(coalesce(v_objeto.get_string('requerido'), 'N'));
            r_def.valores   := v_objeto.get_array('valores');
            if v_codigo is null or not regexp_like(v_codigo, '^[a-z][a-z0-9_]{0,59}$') then
                lanzar_atributos(i_mensaje => 'El código de cada atributo va en minúsculas, sin espacios (ej. talle, potencia_hp).');
            end if;
            if r_def.tipo not in ('T', 'N', 'F', 'S') then
                lanzar_atributos(i_mensaje => 'El tipo del atributo ' || v_codigo || ' debe ser T, N, F o S.');
            end if;
            if r_def.requerido not in ('S', 'N') then
                lanzar_atributos(i_mensaje => 'El indicador requerido del atributo ' || v_codigo || ' debe ser S o N.');
            end if;
            if not io_definiciones.exists(v_codigo) then
                io_definiciones(v_codigo) := r_def;
            end if;
        end loop;
    end agregar_definicion;

    procedure validar_definicion_atributos (
        i_atributos_def  in erp_stk_categoria.atributos_def%type
    ) is
        t_definiciones  t_definicion_mapa;
    begin
        agregar_definicion(i_atributos_def => i_atributos_def, io_definiciones => t_definiciones);
    end validar_definicion_atributos;

    procedure validar_atributos (
        i_categoria_id  in erp_stk_producto.categoria_id%type,
        i_atributos     in erp_stk_producto.atributos%type
    ) is
        t_definiciones  t_definicion_mapa;
        v_objeto        json_object_t;
        v_claves        json_key_list;
        v_codigo        varchar2(100);
        v_elemento      json_element_t;
        v_texto         varchar2(4000);
        v_fecha         date;
        v_encontrado    boolean;
        r_def           t_definicion;
    begin
        -- La categoría hereda las definiciones de sus categorías superiores (la más cercana manda).
        for r in (select atributos_def
                    from erp_stk_categoria
                   start with categoria_id = i_categoria_id
                 connect by nocycle prior categoria_id_padre = categoria_id
                   order by level) loop
            agregar_definicion(i_atributos_def => r.atributos_def, io_definiciones => t_definiciones);
        end loop;

        if i_atributos is not null then
            begin
                v_objeto := json_object_t.parse(i_atributos);
            exception
                when others then
                    lanzar_atributos(i_mensaje => 'Los atributos del producto deben ser un objeto JSON.');
            end;
            v_claves := v_objeto.get_keys;
            if v_claves is not null then
                for i in 1 .. v_claves.count loop
                    v_codigo := v_claves(i);
                    if not t_definiciones.exists(v_codigo) then
                        lanzar_atributos(i_mensaje => 'El atributo "' || v_codigo || '" no está definido para la categoría del producto.');
                    end if;
                    r_def      := t_definiciones(v_codigo);
                    v_elemento := v_objeto.get(v_codigo);
                    if v_elemento is null or v_elemento.is_null then
                        continue;
                    end if;
                    if r_def.tipo = 'N' then
                        if not v_elemento.is_number then
                            lanzar_atributos(i_mensaje => 'El atributo "' || r_def.nombre || '" debe ser un número.');
                        end if;
                        v_texto := to_char(v_objeto.get_number(v_codigo), 'tm9', 'nls_numeric_characters=''.,''');
                    else
                        if not v_elemento.is_string then
                            lanzar_atributos(i_mensaje => 'El atributo "' || r_def.nombre || '" debe ser un texto.');
                        end if;
                        v_texto := v_objeto.get_string(v_codigo);
                        if r_def.tipo = 'S' and v_texto not in ('S', 'N') then
                            lanzar_atributos(i_mensaje => 'El atributo "' || r_def.nombre || '" debe ser S o N.');
                        end if;
                        if r_def.tipo = 'F' then
                            begin
                                v_fecha := to_date(v_texto, 'fxYYYY-MM-DD');
                            exception
                                when others then
                                    lanzar_atributos(i_mensaje => 'El atributo "' || r_def.nombre || '" debe ser una fecha AAAA-MM-DD.');
                            end;
                        end if;
                    end if;
                    if r_def.valores is not null and r_def.valores.get_size > 0 then
                        v_encontrado := false;
                        for j in 0 .. r_def.valores.get_size - 1 loop
                            if r_def.valores.get_string(j) = v_texto then
                                v_encontrado := true;
                                exit;
                            end if;
                        end loop;
                        if not v_encontrado then
                            lanzar_atributos(i_mensaje => 'El valor "' || v_texto || '" no está permitido para el atributo "' || r_def.nombre || '".');
                        end if;
                    end if;
                end loop;
            end if;
        end if;

        -- Requeridos
        v_codigo := t_definiciones.first;
        while v_codigo is not null loop
            if t_definiciones(v_codigo).requerido = 'S'
               and (v_objeto is null or not v_objeto.has(v_codigo) or v_objeto.get(v_codigo).is_null) then
                lanzar_atributos(i_mensaje => 'Falta el atributo obligatorio "' || t_definiciones(v_codigo).nombre || '".');
            end if;
            v_codigo := t_definiciones.next(v_codigo);
        end loop;
    end validar_atributos;

    procedure validar_funcionalidad (
        i_empresa_id  in number,
        i_codigo      in varchar2,
        i_mensaje     in varchar2
    ) is
    begin
        if erp_gen_funcionalidad_api.es_activa_sn(i_codigo => i_codigo, i_empresa_id => i_empresa_id) = 'N' then
            raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, i_mensaje);
        end if;
    end validar_funcionalidad;

    procedure validar (
        io_producto  in out nocopy erp_stk_producto%rowtype
    ) is
        r_anterior  erp_stk_producto%rowtype;
        v_cantidad  pls_integer;
    begin
        io_producto.codigo            := upper(trim(io_producto.codigo));
        io_producto.nombre            := trim(io_producto.nombre);
        io_producto.descripcion_fe    := trim(io_producto.descripcion_fe);
        io_producto.tipo              := coalesce(io_producto.tipo, 'B');
        io_producto.tiene_lote        := coalesce(io_producto.tiene_lote, 'N');
        io_producto.tiene_serie       := coalesce(io_producto.tiene_serie, 'N');
        io_producto.tiene_vencimiento := coalesce(io_producto.tiene_vencimiento, 'N');
        io_producto.factor_compra     := coalesce(io_producto.factor_compra, 1);
        io_producto.factor_venta      := coalesce(io_producto.factor_venta, 1);
        io_producto.estado            := coalesce(io_producto.estado, 'A');

        if io_producto.empresa_id is null or io_producto.codigo is null or io_producto.nombre is null
           or io_producto.unidad_id is null or io_producto.categoria_fiscal_id is null then
            raise_application_error(erp_stk_comun_utl.c_err_dato_invalido,
                'El producto necesita empresa, código, nombre, unidad base y categoría fiscal.');
        end if;

        -- Lo que la empresa no tiene activo no se puede usar
        if io_producto.tiene_lote = 'S' then
            validar_funcionalidad(i_empresa_id => io_producto.empresa_id, i_codigo => 'LOTE',
                                  i_mensaje => 'La empresa no tiene activo el control por lote.');
        end if;
        if io_producto.tiene_serie = 'S' then
            validar_funcionalidad(i_empresa_id => io_producto.empresa_id, i_codigo => 'SERIE',
                                  i_mensaje => 'La empresa no tiene activo el control por número de serie.');
        end if;
        if io_producto.tiene_vencimiento = 'S' then
            validar_funcionalidad(i_empresa_id => io_producto.empresa_id, i_codigo => 'VENCIMIENTO',
                                  i_mensaje => 'La empresa no tiene activo el control de vencimientos.');
        end if;

        -- Categoría y marca de la misma empresa
        if io_producto.categoria_id is not null then
            select count(*) into v_cantidad
              from erp_stk_categoria
             where categoria_id = io_producto.categoria_id and empresa_id = io_producto.empresa_id;
            if v_cantidad = 0 then
                raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'La categoría no pertenece a la empresa.');
            end if;
        end if;
        if io_producto.marca_id is not null then
            select count(*) into v_cantidad
              from erp_stk_marca
             where marca_id = io_producto.marca_id and empresa_id = io_producto.empresa_id;
            if v_cantidad = 0 then
                raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'La marca no pertenece a la empresa.');
            end if;
        end if;

        validar_atributos(i_categoria_id => io_producto.categoria_id, i_atributos => io_producto.atributos);

        -- Con movimientos no se cambia lo que define cómo se lleva el stock
        if io_producto.producto_id is not null then
            r_anterior := erp_stk_producto_ctr.obtener(i_producto_id => io_producto.producto_id);
            if r_anterior.producto_id is null then
                raise_application_error(erp_stk_comun_utl.c_err_no_existe, 'El producto indicado no existe.');
            end if;
            if r_anterior.empresa_id <> io_producto.empresa_id then
                raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'No se puede cambiar la empresa del producto.');
            end if;
            if r_anterior.unidad_id <> io_producto.unidad_id
               or r_anterior.tiene_lote <> io_producto.tiene_lote
               or r_anterior.tiene_serie <> io_producto.tiene_serie
               or (r_anterior.tipo in ('B', 'P') and io_producto.tipo not in ('B', 'P')) then
                select count(*) into v_cantidad
                  from erp_stk_movimiento_item
                 where producto_id = io_producto.producto_id
                   and rownum = 1;
                if v_cantidad > 0 then
                    raise_application_error(erp_stk_comun_utl.c_err_dato_invalido,
                        'El producto ya tiene movimientos: no se puede cambiar su unidad base, su tipo ni el control por lote o serie.');
                end if;
            end if;
        end if;
    end validar;

    function calcular_cantidad_base (
        i_producto_id  in erp_stk_producto.producto_id%type,
        i_unidad_id    in erp_stk_unidad.unidad_id%type,
        i_cantidad     in number
    ) return number is
        r_producto  erp_stk_producto%rowtype;
        v_factor    number;
    begin
        r_producto := erp_stk_producto_ctr.obtener(i_producto_id => i_producto_id);
        if r_producto.producto_id is null then
            raise_application_error(erp_stk_comun_utl.c_err_no_existe, 'El producto indicado no existe.');
        end if;
        if i_unidad_id is null or i_unidad_id = r_producto.unidad_id then
            v_factor := 1;
        else
            begin
                select factor
                  into v_factor
                  from erp_stk_producto_unidad
                 where producto_id = i_producto_id
                   and unidad_id   = i_unidad_id
                   and estado      = 'A';
            exception
                when no_data_found then
                    v_factor := case
                                    when i_unidad_id = r_producto.unidad_id_compra then r_producto.factor_compra
                                    when i_unidad_id = r_producto.unidad_id_venta  then r_producto.factor_venta
                                end;
            end;
        end if;
        if v_factor is null then
            raise_application_error(c_err_conversion,
                'El producto ' || r_producto.codigo || ' no tiene conversión definida para esa unidad.');
        end if;
        return round(i_cantidad * v_factor, 4);
    end calcular_cantidad_base;

end erp_stk_producto_reg;
/

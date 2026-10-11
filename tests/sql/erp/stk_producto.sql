-- =============================================================================
-- Pruebas de inventario: maestros (producto, categoría, atributos, unidades,
-- códigos, lotes, kit, permisos).
--   SQLcl, desde la raíz del repositorio, con el esquema de la app como actual:
--     SQL> @tests/sql/erp/stk_producto.sql
--   Salida: "OK <caso>" / "FALLA <caso>". Termina en rollback: no deja datos.
-- =============================================================================
@@stk_base.sql

declare
    v_emp     number;
    v_ok      pls_integer := 0;
    v_falla   pls_integer := 0;
    v_id      number;
    v_id2     number;
    v_cat     number;
    v_sub     number;
    v_p1      number;
    v_p2      number;
    v_p3      number;
    v_uni     number;
    v_caja    number;
    v_kg      number;
    v_cafi    number;
    v_d1      number;
    r         erp_stk_producto%rowtype;

    procedure verificar (i_caso in varchar2, i_condicion in boolean, i_detalle in varchar2 default null) is
    begin
        if coalesce(i_condicion, false) then
            v_ok := v_ok + 1;
            dbms_output.put_line('OK    ' || i_caso);
        else
            v_falla := v_falla + 1;
            dbms_output.put_line('FALLA ' || i_caso || case when i_detalle is not null then ' -> ' || i_detalle end);
        end if;
    end verificar;

    -- Dentro de "when others": el error debe ser el esperado.
    procedure verificar_error (i_caso in varchar2, i_esperado in number) is
    begin
        verificar(i_caso, sqlcode = i_esperado, 'esperado ' || i_esperado || ', obtenido ' || sqlerrm);
    end verificar_error;

    function base (i_codigo in varchar2) return erp_stk_producto%rowtype is
        r_p  erp_stk_producto%rowtype;
    begin
        r_p.empresa_id          := v_emp;
        r_p.codigo              := i_codigo;
        r_p.nombre              := 'Producto ' || i_codigo;
        r_p.tipo                := 'B';
        r_p.unidad_id           := v_uni;
        r_p.categoria_fiscal_id := v_cafi;
        return r_p;
    end base;
begin
    select empresa_id into v_emp from adm_gen_empresa where codigo = 'STKTEST';
    select producto_id into v_p1 from erp_stk_producto where empresa_id = v_emp and codigo = 'P1';
    select producto_id into v_p2 from erp_stk_producto where empresa_id = v_emp and codigo = 'P2';
    select producto_id into v_p3 from erp_stk_producto where empresa_id = v_emp and codigo = 'P3';
    select unidad_id into v_uni  from erp_stk_unidad where codigo = 'UNI';
    select unidad_id into v_caja from erp_stk_unidad where codigo = 'CAJA';
    select unidad_id into v_kg   from erp_stk_unidad where codigo = 'KG';
    select min(categoria_fiscal_id) into v_cafi from erp_gen_categoria_fiscal where codigo = 'GRAV10';
    select d.deposito_id into v_d1 from erp_stk_deposito d join erp_gen_sucursal s on s.sucursal_id = d.sucursal_id
     where s.empresa_id = v_emp and d.codigo = 'D1';

    -- PR-01 alta con normalización
    r := base(' abc-1 ');
    erp_stk_producto_api.crear(i_producto => r, o_producto_id => v_id);
    select codigo into r.codigo from erp_stk_producto where producto_id = v_id;
    verificar('PR-01 alta de producto: código normalizado a mayúsculas', r.codigo = 'ABC-1', r.codigo);

    -- PR-02 código duplicado en la empresa
    begin
        r := base('ABC-1');
        erp_stk_producto_api.crear(i_producto => r, o_producto_id => v_id2);
        verificar('PR-02 código de producto duplicado rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-02 código de producto duplicado rechazado', -1);
    end;

    -- PR-03 control por lote sin la funcionalidad activa
    update erp_gen_empresa_func set estado = 'I'
     where empresa_id = v_emp and funcionalidad_id = (select funcionalidad_id from erp_gen_funcionalidad where codigo = 'LOTE');
    begin
        r := base('CONLOTE');
        r.tiene_lote := 'S';
        erp_stk_producto_api.crear(i_producto => r, o_producto_id => v_id2);
        verificar('PR-03 lote sin funcionalidad LOTE activa rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-03 lote sin funcionalidad LOTE activa rechazado', -20160);
    end;
    update erp_gen_empresa_func set estado = 'A' where empresa_id = v_emp;

    -- PR-04 categoría en árbol con definición de atributos y herencia
    erp_stk_categoria_api.crear(
        i_empresa_id => v_emp, i_codigo => 'ropa', i_nombre => 'Ropa', i_linea_negocio => 'textil', i_grupo_contable => 'merc_reventa',
        i_atributos_def => '[{"codigo":"temporada","nombre":"Temporada","tipo":"T","valores":["VERANO","INVIERNO"]}]',
        o_categoria_id => v_cat);
    erp_stk_categoria_api.crear(
        i_empresa_id => v_emp, i_codigo => 'REMERAS', i_nombre => 'Remeras', i_categoria_id_padre => v_cat,
        i_atributos_def => '[{"codigo":"talle","nombre":"Talle","tipo":"T","requerido":"S","valores":["S","M","L"]},'
                        || '{"codigo":"gramaje","nombre":"Gramaje","tipo":"N"},{"codigo":"lanzamiento","nombre":"Lanzamiento","tipo":"F"},'
                        || '{"codigo":"importado","nombre":"Importado","tipo":"S"}]',
        o_categoria_id => v_sub);
    verificar('PR-04 línea de negocio heredada de la categoría superior',
              erp_stk_categoria_api.obtener_linea_negocio(i_categoria_id => v_sub) = 'TEXTIL'
              and erp_stk_categoria_api.obtener_grupo_contable(i_categoria_id => v_sub) = 'MERC_REVENTA');

    r := base('REM-1');
    r.categoria_id := v_sub;
    r.atributos    := '{"talle":"M","gramaje":180.5,"lanzamiento":"2026-03-01","importado":"N","temporada":"VERANO"}';
    erp_stk_producto_api.crear(i_producto => r, o_producto_id => v_id2);
    verificar('PR-05 atributos válidos (propios y heredados) aceptados', v_id2 is not null);

    begin
        r := base('REM-2'); r.categoria_id := v_sub; r.atributos := '{"talle":"M","color":"rojo"}';
        erp_stk_producto_api.crear(i_producto => r, o_producto_id => v_id2);
        verificar('PR-06 atributo no definido rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-06 atributo no definido rechazado', -20178);
    end;
    begin
        r := base('REM-3'); r.categoria_id := v_sub; r.atributos := '{"gramaje":150}';
        erp_stk_producto_api.crear(i_producto => r, o_producto_id => v_id2);
        verificar('PR-07 atributo obligatorio faltante rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-07 atributo obligatorio faltante rechazado', -20178);
    end;
    begin
        r := base('REM-4'); r.categoria_id := v_sub; r.atributos := '{"talle":"XXL"}';
        erp_stk_producto_api.crear(i_producto => r, o_producto_id => v_id2);
        verificar('PR-08 valor fuera de la lista rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-08 valor fuera de la lista rechazado', -20178);
    end;
    begin
        r := base('REM-5'); r.categoria_id := v_sub; r.atributos := '{"talle":"S","gramaje":"mucho"}';
        erp_stk_producto_api.crear(i_producto => r, o_producto_id => v_id2);
        verificar('PR-09 atributo numérico con texto rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-09 atributo numérico con texto rechazado', -20178);
    end;
    begin
        r := base('REM-6'); r.categoria_id := v_sub; r.atributos := '{"talle":"S","lanzamiento":"01/03/2026"}';
        erp_stk_producto_api.crear(i_producto => r, o_producto_id => v_id2);
        verificar('PR-10 atributo fecha con formato inválido rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-10 atributo fecha con formato inválido rechazado', -20178);
    end;
    begin
        erp_stk_categoria_api.crear(i_empresa_id => v_emp, i_codigo => 'MALA', i_nombre => 'Mala',
                                    i_atributos_def => '[{"codigo":"Con Espacio","tipo":"T"}]', o_categoria_id => v_id2);
        verificar('PR-11 definición de atributos inválida rechazada', false, 'no dio error');
    exception when others then verificar_error('PR-11 definición de atributos inválida rechazada', -20178);
    end;
    begin
        erp_stk_categoria_api.modificar(i_categoria_id => v_cat, i_codigo => 'ROPA', i_nombre => 'Ropa', i_categoria_id_padre => v_sub,
                                        i_linea_negocio => null, i_grupo_contable => null, i_atributos_def => null, i_estado => 'A');
        verificar('PR-12 ciclo en el árbol de categorías rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-12 ciclo en el árbol de categorías rechazado', -20160);
    end;

    -- PR-13 conversión de unidades
    insert into erp_stk_producto_unidad (producto_id, unidad_id, factor) values (v_p1, v_caja, 12);
    verificar('PR-13 conversión por producto: 2 cajas = 24 unidades',
              erp_stk_producto_api.obtener_cantidad_base(i_producto_id => v_p1, i_unidad_id => v_caja, i_cantidad => 2) = 24);
    update erp_stk_producto set unidad_id_compra = v_caja, factor_compra = 6 where producto_id = v_p2;
    verificar('PR-14 conversión por unidad de compra del producto: 3 cajas = 18',
              erp_stk_producto_api.obtener_cantidad_base(i_producto_id => v_p2, i_unidad_id => v_caja, i_cantidad => 3) = 18
              and erp_stk_producto_api.obtener_cantidad_base(i_producto_id => v_p2, i_unidad_id => v_uni, i_cantidad => 3) = 3);
    begin
        v_id2 := erp_stk_producto_api.obtener_cantidad_base(i_producto_id => v_p1, i_unidad_id => v_kg, i_cantidad => 1);
        verificar('PR-15 unidad sin conversión rechazada', false, 'no dio error');
    exception when others then verificar_error('PR-15 unidad sin conversión rechazada', -20177);
    end;

    -- PR-16 códigos alternativos
    insert into erp_stk_producto_codigo (empresa_id, producto_id, tipo, valor) values (v_emp, v_p1, 'B', '7840001000017');
    insert into erp_stk_producto_codigo (empresa_id, producto_id, tipo, valor, unidad_id, factor) values (v_emp, v_p1, 'C', '17840001000014', v_caja, 12);
    verificar('PR-16 búsqueda por código interno y por código de barras',
              erp_stk_producto_api.obtener_id(i_empresa_id => v_emp, i_codigo => 'p1') = v_p1
              and erp_stk_producto_api.obtener_id(i_empresa_id => v_emp, i_codigo => '7840001000017') = v_p1
              and erp_stk_producto_api.obtener_id(i_empresa_id => v_emp, i_codigo => 'NOEXISTE') is null);
    begin
        insert into erp_stk_producto_codigo (empresa_id, producto_id, tipo, valor) values (v_emp, v_p2, 'B', '7840001000017');
        verificar('PR-17 código de barras repetido en la empresa rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-17 código de barras repetido en la empresa rechazado', -1);
    end;

    -- PR-18..21 lotes y series
    begin
        erp_stk_lote_api.crear(i_producto_id => v_p2, i_codigo => 'SINVENC', o_lote_id => v_id2);
        verificar('PR-18 lote sin vencimiento en producto que lo exige rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-18 lote sin vencimiento en producto que lo exige rechazado', -20163);
    end;
    begin
        erp_stk_lote_api.crear(i_producto_id => v_p1, i_codigo => 'X', o_lote_id => v_id2);
        verificar('PR-19 lote en producto que no maneja lote rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-19 lote en producto que no maneja lote rechazado', -20163);
    end;
    erp_stk_lote_api.crear(i_producto_id => v_p3, i_codigo => 'sn-001', o_lote_id => v_id2);
    select tipo into r.tipo from erp_stk_lote where lote_id = v_id2;
    verificar('PR-20 la serie se crea como lote de tipo S y se encuentra por código',
              r.tipo = 'S' and erp_stk_lote_api.obtener_id(i_producto_id => v_p3, i_codigo => 'SN-001') = v_id2);
    update erp_stk_producto set dias_vida_util = 30 where producto_id = v_p2;
    erp_stk_lote_api.crear(i_producto_id => v_p2, i_codigo => 'LVIDA', i_fecha_elaboracion => date '2026-01-01', o_lote_id => v_id2);
    select fecha_vencimiento into r.fecha_creacion from erp_stk_lote where lote_id = v_id2;
    verificar('PR-21 vencimiento calculado con la vida útil del producto', trunc(cast(r.fecha_creacion as date)) = date '2026-01-31');

    -- PR-22..24 reglas por constraint
    begin
        r := base('SRVLOTE'); r.tipo := 'S'; r.tiene_lote := 'S';
        erp_stk_producto_api.crear(i_producto => r, o_producto_id => v_id2);
        verificar('PR-22 servicio con lote rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-22 servicio con lote rechazado', -2290);
    end;
    begin
        r := base('METODO'); r.metodo_costo := 'X';
        erp_stk_producto_api.crear(i_producto => r, o_producto_id => v_id2);
        verificar('PR-23 método de costo inválido rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-23 método de costo inválido rechazado', -2290);
    end;
    r := base('KIT-1'); r.tipo := 'K';
    erp_stk_producto_api.crear(i_producto => r, o_producto_id => v_id2);
    insert into erp_stk_kit (producto_id, producto_id_componente, cantidad) values (v_id2, v_p1, 2);
    begin
        insert into erp_stk_kit (producto_id, producto_id_componente, cantidad) values (v_id2, v_id2, 1);
        verificar('PR-24 kit: componente válido aceptado y kit dentro de sí mismo rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-24 kit: componente válido aceptado y kit dentro de sí mismo rechazado', -2290);
    end;

    -- PR-25 con movimientos no se cambia la unidad base
    erp_stk_movimiento_api.crear_ajuste_entrada(i_empresa_id => v_emp, i_deposito_id => v_d1, i_producto_id => v_p1,
                                                i_cantidad => 5, i_motivo => 'Prueba', i_costo_unitario => 1000, o_movimiento_id => v_id2);
    begin
        select * into r from erp_stk_producto where producto_id = v_p1;
        r.unidad_id := v_kg;
        erp_stk_producto_api.modificar(i_producto => r);
        verificar('PR-25 cambio de unidad base con movimientos rechazado', false, 'no dio error');
    exception when others then verificar_error('PR-25 cambio de unidad base con movimientos rechazado', -20160);
    end;
    select * into r from erp_stk_producto where producto_id = v_p1;
    r.nombre := 'Producto P1 modificado';
    r.peso_neto := 1.25;
    erp_stk_producto_api.modificar(i_producto => r);
    select nombre into r.nombre from erp_stk_producto where producto_id = v_p1;
    verificar('PR-26 modificación de datos generales aceptada', r.nombre = 'Producto P1 modificado');

    -- PR-27..28 permisos
    erp_stk_comun_utl.asignar_usuario(i_username => 'STK_QA_C');
    begin
        r := base('SINPERMISO');
        erp_stk_producto_api.crear(i_producto => r, o_producto_id => v_id2);
        verificar('PR-27 usuario sin permiso no crea productos', false, 'no dio error');
    exception when others then verificar_error('PR-27 usuario sin permiso no crea productos', -20161);
    end;
    erp_stk_comun_utl.asignar_usuario(i_username => 'STK_QA_A');
    r := base('CONPERMISO');
    erp_stk_producto_api.crear(i_producto => r, o_producto_id => v_id2);
    select creado_por into r.creado_por from erp_stk_producto where producto_id = v_id2;
    verificar('PR-28 usuario con permiso crea productos', v_id2 is not null);
    erp_stk_comun_utl.asignar_usuario(i_username => null);

    dbms_output.put_line('RESUMEN stk_producto: ' || v_ok || ' OK, ' || v_falla || ' FALLA');
end;
/
rollback;

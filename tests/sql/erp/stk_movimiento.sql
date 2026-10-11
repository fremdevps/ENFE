-- =============================================================================
-- Pruebas de inventario: motor de movimientos (ajustes, saldo negativo según el
-- depósito, reservas, lote / serie / vencimiento, período cerrado, reverso,
-- depósitos de tránsito, ubicaciones, permisos).
--   SQL> @tests/sql/erp/stk_movimiento.sql      (termina en rollback)
-- =============================================================================
@@stk_base.sql

declare
    v_emp     number;
    v_ok      pls_integer := 0;
    v_falla   pls_integer := 0;
    v_mov     number;
    v_mov2    number;
    v_rev     number;
    v_n       number;
    v_hoy     date := trunc(current_date);
    v_d1 number; v_d1b number; v_d1n number; v_t1 number; v_d2 number;
    v_p1 number; v_p2 number; v_p3 number; v_pkg number; v_srv number;
    v_l1 number; v_lvenc number; v_sn number;
    v_ubi_a number; v_ubi_b number; v_ubi_q number;
    r_saldo   erp_stk_saldo%rowtype;
    r_mov     erp_stk_movimiento%rowtype;

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

    procedure verificar_error (i_caso in varchar2, i_esperado in number) is
    begin
        verificar(i_caso, sqlcode = i_esperado, 'esperado ' || i_esperado || ', obtenido ' || sqlerrm);
    end verificar_error;

    function deposito (i_codigo in varchar2) return number is
        v_id  number;
    begin
        select d.deposito_id into v_id from erp_stk_deposito d join erp_gen_sucursal s on s.sucursal_id = d.sucursal_id
         where s.empresa_id = v_emp and d.codigo = i_codigo;
        return v_id;
    end deposito;

    function producto (i_codigo in varchar2) return number is
        v_id  number;
    begin
        select producto_id into v_id from erp_stk_producto where empresa_id = v_emp and codigo = i_codigo;
        return v_id;
    end producto;

    function saldo (i_deposito in number, i_producto in number, i_lote in number default null, i_ubicacion in number default null)
        return erp_stk_saldo%rowtype is
        r  erp_stk_saldo%rowtype;
    begin
        select * into r from erp_stk_saldo
         where deposito_id = i_deposito and producto_id = i_producto
           and coalesce(lote_id, 0) = coalesce(i_lote, 0) and coalesce(deposito_ubicacion_id, 0) = coalesce(i_ubicacion, 0);
        return r;
    exception when no_data_found then
        r.cantidad := 0; r.cantidad_reservada := 0;
        return r;
    end saldo;

    procedure entrada (i_deposito in number, i_producto in number, i_cantidad in number, i_costo in number,
                       i_lote in number default null, i_ubicacion in number default null) is
    begin
        erp_stk_movimiento_api.crear_ajuste_entrada(
            i_empresa_id => v_emp, i_deposito_id => i_deposito, i_producto_id => i_producto, i_cantidad => i_cantidad,
            i_motivo => 'Carga de prueba', i_costo_unitario => i_costo, i_lote_id => i_lote,
            i_deposito_ubicacion_id => i_ubicacion, o_movimiento_id => v_mov);
    end entrada;

    procedure salida (i_deposito in number, i_producto in number, i_cantidad in number, i_lote in number default null) is
    begin
        erp_stk_movimiento_api.crear_ajuste_salida(
            i_empresa_id => v_emp, i_deposito_id => i_deposito, i_producto_id => i_producto, i_cantidad => i_cantidad,
            i_motivo => 'Salida de prueba', i_lote_id => i_lote, o_movimiento_id => v_mov);
    end salida;

    procedure registrar (i_tipo in varchar2, i_items in erp_stk_mov_item_tab, i_fecha in date default trunc(current_date)) is
    begin
        erp_stk_movimiento_api.registrar(i_empresa_id => v_emp, i_tipo_movimiento => i_tipo, i_fecha => i_fecha,
                                         i_items => i_items, i_motivo => 'Prueba', o_movimiento_id => v_mov);
    end registrar;
begin
    select empresa_id into v_emp from adm_gen_empresa where codigo = 'STKTEST';
    v_d1 := deposito('D1'); v_d1b := deposito('D1B'); v_d1n := deposito('D1N'); v_t1 := deposito('T1'); v_d2 := deposito('D2');
    v_p1 := producto('P1'); v_p2 := producto('P2'); v_p3 := producto('P3'); v_pkg := producto('PKG'); v_srv := producto('SRV');
    select lote_id into v_l1 from erp_stk_lote where producto_id = v_p2 and codigo = 'L1';
    select lote_id into v_lvenc from erp_stk_lote where producto_id = v_p2 and codigo = 'LVENC';

    -- MV-01 ajuste de entrada
    entrada(v_d1, v_p1, 100, 10000);
    r_saldo := saldo(v_d1, v_p1);
    select count(*), max(saldo_cantidad) into v_n, v_mov2 from erp_stk_movimiento_item where movimiento_id = v_mov;
    verificar('MV-01 ajuste de entrada: saldo 100 y una línea con el saldo resultante',
              r_saldo.cantidad = 100 and r_saldo.costo_promedio = 10000 and v_n = 1 and v_mov2 = 100);

    -- MV-02 saldo negativo rechazado si el depósito controla stock
    begin
        salida(v_d1, v_p1, 101);
        verificar('MV-02 salida mayor al saldo rechazada en depósito que controla stock', false, 'no dio error');
    exception when others then verificar_error('MV-02 salida mayor al saldo rechazada en depósito que controla stock', -20162);
    end;
    verificar('MV-02b el saldo no cambió tras el rechazo', saldo(v_d1, v_p1).cantidad = 100);

    -- MV-03 saldo negativo permitido si el depósito no controla stock
    salida(v_d1n, v_p1, 15);
    verificar('MV-03 salida sin saldo permitida en depósito que no controla stock (queda -15)', saldo(v_d1n, v_p1).cantidad = -15);

    -- MV-04 motivo obligatorio
    begin
        erp_stk_movimiento_api.crear_ajuste_entrada(i_empresa_id => v_emp, i_deposito_id => v_d1, i_producto_id => v_p1,
                                                    i_cantidad => 1, i_motivo => '  ', o_movimiento_id => v_mov2);
        verificar('MV-04 ajuste sin motivo rechazado', false, 'no dio error');
    exception when others then verificar_error('MV-04 ajuste sin motivo rechazado', -20160);
    end;

    -- MV-05..07 reservas
    erp_stk_movimiento_api.reservar(i_empresa_id => v_emp, i_deposito_id => v_d1, i_producto_id => v_p1, i_cantidad => 30);
    verificar('MV-05 reserva: saldo 100, reservado 30, disponible 70',
              saldo(v_d1, v_p1).cantidad = 100 and saldo(v_d1, v_p1).cantidad_reservada = 30
              and erp_stk_movimiento_api.obtener_disponible(i_empresa_id => v_emp, i_deposito_id => v_d1, i_producto_id => v_p1) = 70);
    begin
        salida(v_d1, v_p1, 80);
        verificar('MV-06 salida que toca lo reservado rechazada', false, 'no dio error');
    exception when others then verificar_error('MV-06 salida que toca lo reservado rechazada', -20162);
    end;
    begin
        erp_stk_movimiento_api.reservar(i_empresa_id => v_emp, i_deposito_id => v_d1, i_producto_id => v_p1, i_cantidad => 71);
        verificar('MV-07 reserva mayor al disponible rechazada', false, 'no dio error');
    exception when others then verificar_error('MV-07 reserva mayor al disponible rechazada', -20162);
    end;
    begin
        erp_stk_movimiento_api.liberar_reserva(i_empresa_id => v_emp, i_deposito_id => v_d1, i_producto_id => v_p1, i_cantidad => 31);
        verificar('MV-08 liberar más de lo reservado rechazado', false, 'no dio error');
    exception when others then verificar_error('MV-08 liberar más de lo reservado rechazado', -20168);
    end;
    erp_stk_movimiento_api.liberar_reserva(i_empresa_id => v_emp, i_deposito_id => v_d1, i_producto_id => v_p1, i_cantidad => 30);
    verificar('MV-09 liberación: reservado 0 y disponible 100',
              saldo(v_d1, v_p1).cantidad_reservada = 0
              and erp_stk_movimiento_api.obtener_disponible(i_empresa_id => v_emp, i_deposito_id => v_d1, i_producto_id => v_p1) = 100);
    -- salida que consume su propia reserva en la misma operación (como hará una factura con pedido)
    erp_stk_movimiento_api.reservar(i_empresa_id => v_emp, i_deposito_id => v_d1, i_producto_id => v_p1, i_cantidad => 100);
    registrar('VENTA', erp_stk_mov_item_tab(erp_stk_mov_item_typ(deposito_id => v_d1, producto_id => v_p1, cantidad => -40, reserva => -40)));
    verificar('MV-10 salida que libera su reserva en la misma línea: saldo 60, reservado 60',
              saldo(v_d1, v_p1).cantidad = 60 and saldo(v_d1, v_p1).cantidad_reservada = 60);
    erp_stk_movimiento_api.liberar_reserva(i_empresa_id => v_emp, i_deposito_id => v_d1, i_producto_id => v_p1, i_cantidad => 60);

    -- MV-11..14 lote obligatorio y vencimiento
    begin
        entrada(v_d1, v_p2, 10, 500);
        verificar('MV-11 producto con lote: movimiento sin lote rechazado', false, 'no dio error');
    exception when others then verificar_error('MV-11 producto con lote: movimiento sin lote rechazado', -20163);
    end;
    begin
        entrada(v_d1, v_p1, 10, 500, v_l1);
        verificar('MV-12 lote de otro producto / producto sin lote rechazado', false, 'no dio error');
    exception when others then verificar_error('MV-12 lote de otro producto / producto sin lote rechazado', -20163);
    end;
    entrada(v_d1, v_p2, 20, 500, v_l1);
    entrada(v_d1, v_p2, 5, 500, v_lvenc);
    verificar('MV-13 saldo separado por lote', saldo(v_d1, v_p2, v_l1).cantidad = 20 and saldo(v_d1, v_p2, v_lvenc).cantidad = 5
              and erp_stk_movimiento_api.obtener_saldo(i_empresa_id => v_emp, i_producto_id => v_p2, i_deposito_id => v_d1) = 25);
    begin
        registrar('VENTA', erp_stk_mov_item_tab(erp_stk_mov_item_typ(deposito_id => v_d1, producto_id => v_p2, cantidad => -1, lote_id => v_lvenc)));
        verificar('MV-14 venta de un lote vencido rechazada', false, 'no dio error');
    exception when others then verificar_error('MV-14 venta de un lote vencido rechazada', -20164);
    end;
    registrar('BAJA', erp_stk_mov_item_tab(erp_stk_mov_item_typ(deposito_id => v_d1, producto_id => v_p2, cantidad => -5, lote_id => v_lvenc)));
    verificar('MV-15 baja de un lote vencido permitida', saldo(v_d1, v_p2, v_lvenc).cantidad = 0);
    update erp_stk_lote set estado = 'B' where lote_id = v_l1;
    begin
        salida(v_d1, v_p2, 1, v_l1);
        verificar('MV-16 salida de un lote bloqueado rechazada', false, 'no dio error');
    exception when others then verificar_error('MV-16 salida de un lote bloqueado rechazada', -20163);
    end;
    update erp_stk_lote set estado = 'A' where lote_id = v_l1;

    -- MV-17 números de serie
    erp_stk_lote_api.crear(i_producto_id => v_p3, i_codigo => 'SN-1', o_lote_id => v_sn);
    begin
        entrada(v_d1, v_p3, 2, 900000, v_sn);
        verificar('MV-17 dos unidades de la misma serie rechazadas', false, 'no dio error');
    exception when others then verificar_error('MV-17 dos unidades de la misma serie rechazadas', -20163);
    end;
    entrada(v_d1, v_p3, 1, 900000, v_sn);
    begin
        entrada(v_d1b, v_p3, 1, 900000, v_sn);
        verificar('MV-18 la misma serie en otro depósito rechazada', false, 'no dio error');
    exception when others then verificar_error('MV-18 la misma serie en otro depósito rechazada', -20163);
    end;

    -- MV-19 período cerrado
    insert into erp_gen_periodo (empresa_id, modulo, anio, mes, estado)
    values (v_emp, 'STK', extract(year from add_months(v_hoy, -2)), extract(month from add_months(v_hoy, -2)), 'C');
    begin
        erp_stk_movimiento_api.crear_ajuste_entrada(i_empresa_id => v_emp, i_deposito_id => v_d1, i_producto_id => v_p1, i_cantidad => 1,
                                                    i_motivo => 'Fuera de período', i_fecha => add_months(v_hoy, -2), o_movimiento_id => v_mov2);
        verificar('MV-19 movimiento con fecha en período STK cerrado rechazado', false, 'no dio error');
    exception when others then verificar_error('MV-19 movimiento con fecha en período STK cerrado rechazado', -20106);
    end;

    -- MV-20..23 anulación por reverso
    entrada(v_d1b, v_p1, 50, 8000);
    v_mov2 := v_mov;
    erp_stk_movimiento_api.anular(i_movimiento_id => v_mov2, i_motivo => 'Error de carga', o_movimiento_id => v_rev);
    select * into r_mov from erp_stk_movimiento where movimiento_id = v_rev;
    select estado into r_mov.estado from erp_stk_movimiento where movimiento_id = v_mov2;
    select sum(cantidad) into v_n from erp_stk_movimiento_item where movimiento_id in (v_mov2, v_rev);
    verificar('MV-20 anular = movimiento de reverso: saldo 0, original en R, nada se borra',
              saldo(v_d1b, v_p1).cantidad = 0 and r_mov.es_reverso = 'S' and r_mov.movimiento_id_reversado = v_mov2
              and r_mov.estado = 'R' and v_n = 0);
    begin
        erp_stk_movimiento_api.anular(i_movimiento_id => v_mov2, i_motivo => 'Otra vez', o_movimiento_id => v_n);
        verificar('MV-21 anular dos veces rechazado', false, 'no dio error');
    exception when others then verificar_error('MV-21 anular dos veces rechazado', -20167);
    end;
    begin
        erp_stk_movimiento_api.anular(i_movimiento_id => v_rev, i_motivo => 'Reverso del reverso', o_movimiento_id => v_n);
        verificar('MV-22 anular un reverso rechazado', false, 'no dio error');
    exception when others then verificar_error('MV-22 anular un reverso rechazado', -20167);
    end;
    entrada(v_d1b, v_p1, 50, 8000);
    v_mov2 := v_mov;
    salida(v_d1b, v_p1, 30);
    begin
        erp_stk_movimiento_api.anular(i_movimiento_id => v_mov2, i_motivo => 'Ya se consumió', o_movimiento_id => v_n);
        verificar('MV-23 anular una entrada ya consumida rechazado (no deja negativo)', false, 'no dio error');
    exception when others then verificar_error('MV-23 anular una entrada ya consumida rechazado (no deja negativo)', -20162);
    end;

    -- MV-24..25 depósitos de tránsito (CP-22)
    begin
        registrar('VENTA', erp_stk_mov_item_tab(erp_stk_mov_item_typ(deposito_id => v_t1, producto_id => v_p1, cantidad => -1)));
        verificar('MV-24 venta desde un depósito de tránsito rechazada', false, 'no dio error');
    exception when others then verificar_error('MV-24 venta desde un depósito de tránsito rechazada', -20165);
    end;
    begin
        erp_stk_movimiento_api.reservar(i_empresa_id => v_emp, i_deposito_id => v_t1, i_producto_id => v_p1, i_cantidad => 1);
        verificar('MV-25 reserva en un depósito de tránsito rechazada', false, 'no dio error');
    exception when others then verificar_error('MV-25 reserva en un depósito de tránsito rechazada', -20165);
    end;

    -- MV-26..29 validaciones de línea
    begin
        entrada(v_d1, v_srv, 1, 100);
        verificar('MV-26 movimiento de un servicio rechazado', false, 'no dio error');
    exception when others then verificar_error('MV-26 movimiento de un servicio rechazado', -20166);
    end;
    begin
        registrar('AJUSTE_ENT', erp_stk_mov_item_tab(erp_stk_mov_item_typ(deposito_id => v_d1, producto_id => v_p1, cantidad => -1)));
        verificar('MV-27 tipo de entrada con cantidad negativa rechazado', false, 'no dio error');
    exception when others then verificar_error('MV-27 tipo de entrada con cantidad negativa rechazado', -20160);
    end;
    begin
        entrada(v_d1, v_p1, 1.5, 100);
        verificar('MV-28 cantidad con decimales en unidad entera rechazada', false, 'no dio error');
    exception when others then verificar_error('MV-28 cantidad con decimales en unidad entera rechazada', -20160);
    end;
    entrada(v_d1, v_pkg, 1.2575, 100);
    verificar('MV-29 cantidad con 4 decimales en kilos aceptada', saldo(v_d1, v_pkg).cantidad = 1.2575);
    update erp_stk_producto set estado = 'I' where producto_id = v_pkg;
    begin
        entrada(v_d1, v_pkg, 1, 100);
        verificar('MV-30 producto inactivo rechazado', false, 'no dio error');
    exception when others then verificar_error('MV-30 producto inactivo rechazado', -20166);
    end;

    -- MV-31..34 ubicaciones (funcionalidad activable) y cuarentena
    insert into erp_stk_deposito_ubicacion (deposito_id, codigo, nombre, tipo) values (v_d2, 'A-01', 'Estante A-01', 'A') returning deposito_ubicacion_id into v_ubi_a;
    insert into erp_stk_deposito_ubicacion (deposito_id, codigo, nombre, tipo) values (v_d2, 'A-02', 'Estante A-02', 'A') returning deposito_ubicacion_id into v_ubi_b;
    insert into erp_stk_deposito_ubicacion (deposito_id, codigo, nombre, tipo, es_disponible) values (v_d2, 'CUAR', 'Cuarentena', 'C', 'N') returning deposito_ubicacion_id into v_ubi_q;
    begin
        entrada(v_d2, v_p1, 10, 10000, null, v_ubi_a);
        verificar('MV-31 ubicación sin la funcionalidad UBICACION activa rechazada', false, 'no dio error');
    exception when others then verificar_error('MV-31 ubicación sin la funcionalidad UBICACION activa rechazada', -20169);
    end;
    insert into erp_gen_empresa_func (empresa_id, funcionalidad_id)
    select v_emp, funcionalidad_id from erp_gen_funcionalidad where codigo = 'UBICACION';
    entrada(v_d2, v_p1, 10, 10000, null, v_ubi_a);
    registrar('REUBICACION', erp_stk_mov_item_tab(
        erp_stk_mov_item_typ(deposito_id => v_d2, producto_id => v_p1, cantidad => -4, deposito_ubicacion_id => v_ubi_a),
        erp_stk_mov_item_typ(deposito_id => v_d2, producto_id => v_p1, cantidad => 4, deposito_ubicacion_id => v_ubi_b, linea_costo => 1)));
    verificar('MV-32 cambio de ubicación: 6 y 4, al mismo costo',
              saldo(v_d2, v_p1, null, v_ubi_a).cantidad = 6 and saldo(v_d2, v_p1, null, v_ubi_b).cantidad = 4
              and saldo(v_d2, v_p1, null, v_ubi_b).costo_promedio = 10000);
    begin
        entrada(v_d1, v_p1, 1, 100, null, v_ubi_a);
        verificar('MV-33 ubicación de otro depósito rechazada', false, 'no dio error');
    exception when others then verificar_error('MV-33 ubicación de otro depósito rechazada', -20169);
    end;
    entrada(v_d2, v_p1, 3, 10000, null, v_ubi_q);
    verificar('MV-34 el stock en cuarentena no está disponible: saldo 13, disponible 10',
              erp_stk_movimiento_api.obtener_saldo(i_empresa_id => v_emp, i_producto_id => v_p1, i_deposito_id => v_d2) = 13
              and erp_stk_movimiento_api.obtener_disponible(i_empresa_id => v_emp, i_deposito_id => v_d2, i_producto_id => v_p1) = 10);
    begin
        erp_stk_movimiento_api.reservar(i_empresa_id => v_emp, i_deposito_id => v_d2, i_producto_id => v_p1, i_cantidad => 1, i_deposito_ubicacion_id => v_ubi_q);
        verificar('MV-35 reserva sobre cuarentena rechazada', false, 'no dio error');
    exception when others then verificar_error('MV-35 reserva sobre cuarentena rechazada', -20168);
    end;

    -- MV-36..37 movimiento genérico con origen (como lo usarán compras y ventas)
    erp_stk_movimiento_api.registrar(
        i_empresa_id => v_emp, i_tipo_movimiento => 'COMPRA', i_fecha => v_hoy,
        i_items => erp_stk_mov_item_tab(
                       erp_stk_mov_item_typ(deposito_id => v_d1, producto_id => v_p1, cantidad => 10, costo_unitario => 11000, origen_linea_id => 501),
                       erp_stk_mov_item_typ(deposito_id => v_d1, producto_id => v_p2, cantidad => 6, lote_id => v_l1, costo_unitario => 600, origen_linea_id => 502)),
        i_origen_modulo => 'com', i_origen_tabla => 'ERP_COM_FACTURA', i_origen_id => 9001, o_movimiento_id => v_mov);
    select * into r_mov from erp_stk_movimiento where movimiento_id = v_mov;
    select count(*) into v_n from erp_stk_movimiento_item where movimiento_id = v_mov and origen_linea_id in (501, 502);
    verificar('MV-36 movimiento genérico de varias líneas con origen de documento',
              r_mov.origen_modulo = 'COM' and r_mov.origen_tabla = 'erp_com_factura' and r_mov.origen_id = 9001 and v_n = 2);
    begin
        erp_stk_movimiento_api.anular(i_movimiento_id => v_mov, i_motivo => 'Desde inventario', o_movimiento_id => v_n);
        verificar('MV-37 movimiento de un documento no se anula desde inventario', false, 'no dio error');
    exception when others then verificar_error('MV-37 movimiento de un documento no se anula desde inventario', -20167);
    end;
    erp_stk_movimiento_reg.generar_reverso(i_movimiento_id => v_mov, i_fecha => v_hoy, i_motivo => 'Anulación de la factura', o_movimiento_id => v_rev);
    select origen_id into v_n from erp_stk_movimiento where movimiento_id = v_rev;
    verificar('MV-38 el módulo dueño del documento sí lo reversa (capa reg) y conserva el origen', v_n = 9001);

    -- MV-39 vista de stock por producto
    select cantidad, cantidad_disponible, cantidad_cuarentena into v_n, v_mov2, v_rev
      from erp_stk_saldo_producto_v where empresa_id = v_emp and deposito_id = v_d2 and producto_id = v_p1;
    verificar('MV-39 vista erp_stk_saldo_producto_v: 13 / 10 disponibles / 3 en cuarentena', v_n = 13 and v_mov2 = 10 and v_rev = 3);

    -- MV-40..41 permisos y configuración
    erp_stk_comun_utl.asignar_usuario(i_username => 'STK_QA_C');
    begin
        entrada(v_d1, v_p1, 1, 100);
        verificar('MV-40 usuario sin permiso no registra movimientos', false, 'no dio error');
    exception when others then verificar_error('MV-40 usuario sin permiso no registra movimientos', -20161);
    end;
    erp_stk_comun_utl.asignar_usuario(i_username => 'STK_QA_B');
    entrada(v_d1, v_p1, 1, 10000);
    select creado_por into r_mov.creado_por from erp_stk_movimiento where movimiento_id = v_mov;
    verificar('MV-41 el movimiento guarda el usuario que lo registró', r_mov.creado_por = 'STK_QA_B', r_mov.creado_por);
    erp_stk_comun_utl.asignar_usuario(i_username => null);
    delete from erp_gen_cotizacion where empresa_id = v_emp;
    update erp_gen_empresa_config set moneda_id_reporte = null where empresa_id = v_emp;
    entrada(v_d1, v_p1, 1, 10000);
    select costo_unitario_reporte into v_n from erp_stk_movimiento_item where movimiento_id = v_mov;
    verificar('MV-42 empresa sin moneda de reporte: el costo de reporte queda en 0', v_n = 0);
    delete from erp_gen_empresa_config where empresa_id = v_emp;
    begin
        entrada(v_d1, v_p1, 1, 100);
        verificar('MV-43 empresa sin moneda funcional configurada rechazada', false, 'no dio error');
    exception when others then verificar_error('MV-43 empresa sin moneda funcional configurada rechazada', -20160);
    end;

    dbms_output.put_line('RESUMEN stk_movimiento: ' || v_ok || ' OK, ' || v_falla || ' FALLA');
end;
/
rollback;

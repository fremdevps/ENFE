-- =============================================================================
-- Pruebas de inventario: datos base de la empresa de prueba STKTEST.
-- Lo incluyen los scripts stk_*.sql. No confirma (cada prueba termina en rollback).
--
--   Moneda funcional PYG, de reporte USD (1 USD = 7.000 PYG).
--   Funcionalidades activas: LOTE, VENCIMIENTO, SERIE, FLETE (UBICACION no).
--   Sucursal S1: D1 (controla stock), D1B (controla), D1N (no controla), T1 (tránsito)
--   Sucursal S2: D2 (controla), T2 (tránsito)        Ruta S1 -> S2: 300 km, 6 horas
--   Productos: P1 (unidad), P2 (lote y vencimiento), P3 (serie), PKG (kilos), SRV (servicio)
--   Lotes de P2: L1 (vigente), LVENC (vencido)       Vehículo ABC123 con conductor
--   Usuarios: STK_QA_A (administrador ERP, solo sucursal S1), STK_QA_B (administrador
--   ERP, todas las sucursales), STK_QA_C (sin permisos de inventario)
-- =============================================================================
set serveroutput on size unlimited
set feedback off
set define off
@@stk_limpieza.sql

declare
    v_emp       number;
    v_pais      number;
    v_pyg       number;
    v_usd       number;
    v_s1        number;
    v_s2        number;
    v_cafi      number;
    v_uni       number;
    v_kg        number;
    v_caja      number;
    v_persona   number;
    v_tdi       number;
    v_rol_adm   number;
    v_rol_usu   number;
    v_usuario   number;
    v_id        number;
    r_producto  erp_stk_producto%rowtype;

    procedure crear_deposito (i_sucursal in number, i_codigo in varchar2, i_tipo in varchar2, i_controla in varchar2) is
    begin
        insert into erp_stk_deposito (sucursal_id, codigo, nombre, tipo, debe_controlar_stock)
        values (i_sucursal, i_codigo, 'Depósito ' || i_codigo, i_tipo, i_controla);
    end crear_deposito;

    procedure crear_usuario (i_username in varchar2, i_rol_id in number, i_sucursal_id in number) is
    begin
        insert into adm_seg_usuario (username, email, nombres, tipo_autenticacion, debe_cambiar_password)
        values (i_username, lower(i_username) || '@prueba.local', 'Prueba inventario', 'SSO', 'N')
        returning usuario_id into v_usuario;
        insert into adm_seg_usuario_rol (usuario_id, rol_id, empresa_id) values (v_usuario, i_rol_id, v_emp);
        if i_sucursal_id is not null then
            insert into erp_gen_usuario_sucursal (usuario_id, sucursal_id) values (v_usuario, i_sucursal_id);
        end if;
    end crear_usuario;

    procedure crear_producto (i_codigo in varchar2, i_tipo in varchar2, i_unidad in number,
                              i_lote in varchar2, i_serie in varchar2, i_venc in varchar2) is
    begin
        r_producto := null;
        r_producto.empresa_id          := v_emp;
        r_producto.codigo              := i_codigo;
        r_producto.nombre              := 'Producto ' || i_codigo;
        r_producto.tipo                := i_tipo;
        r_producto.unidad_id           := i_unidad;
        r_producto.categoria_fiscal_id := v_cafi;
        r_producto.tiene_lote          := i_lote;
        r_producto.tiene_serie         := i_serie;
        r_producto.tiene_vencimiento   := i_venc;
        erp_stk_producto_api.crear(i_producto => r_producto, o_producto_id => v_id);
    end crear_producto;
begin
    erp_stk_comun_utl.asignar_usuario(i_username => null);

    insert into adm_gen_empresa (codigo, razon_social) values ('STKTEST', 'Empresa de prueba de inventario')
    returning empresa_id into v_emp;
    select pais_id into v_pais from erp_gen_pais where codigo = 'PY';
    select moneda_id into v_pyg from erp_gen_moneda where codigo = 'PYG';
    select moneda_id into v_usd from erp_gen_moneda where codigo = 'USD';
    insert into erp_gen_empresa_config (empresa_id, pais_id, moneda_id_funcional, moneda_id_reporte)
    values (v_emp, v_pais, v_pyg, v_usd);
    insert into erp_gen_cotizacion (empresa_id, moneda_id_origen, moneda_id_destino, fecha, tasa_compra, tasa_venta)
    values (v_emp, v_usd, v_pyg, date '2020-01-01', 7000, 7000);
    insert into erp_gen_empresa_func (empresa_id, funcionalidad_id)
    select v_emp, funcionalidad_id from erp_gen_funcionalidad where codigo in ('LOTE', 'VENCIMIENTO', 'SERIE', 'FLETE');

    insert into erp_gen_sucursal (empresa_id, codigo, nombre, establecimiento, direccion)
    values (v_emp, 'S1', 'Casa central', '001', 'Avda. Uno 100') returning sucursal_id into v_s1;
    insert into erp_gen_sucursal (empresa_id, codigo, nombre, establecimiento, direccion)
    values (v_emp, 'S2', 'Sucursal dos', '002', 'Ruta Dos km 300') returning sucursal_id into v_s2;
    crear_deposito(v_s1, 'D1',  'P', 'S');
    crear_deposito(v_s1, 'D1B', 'P', 'S');
    crear_deposito(v_s1, 'D1N', 'P', 'N');
    crear_deposito(v_s1, 'T1',  'T', 'S');
    crear_deposito(v_s2, 'D2',  'P', 'S');
    crear_deposito(v_s2, 'T2',  'T', 'S');
    insert into erp_stk_ruta_traslado (empresa_id, sucursal_id_origen, sucursal_id_destino, kilometros, horas_estimadas)
    values (v_emp, v_s1, v_s2, 300, 6);

    -- Conductor y vehículo
    select min(tipo_doc_identidad_id) keep (dense_rank first order by es_tributario, tipo_doc_identidad_id)
      into v_tdi from erp_gen_tipo_doc_identidad where pais_id = v_pais;
    insert into erp_gen_persona (tipo_persona, tipo_doc_identidad_id, nro_documento, razon_social, pais_id)
    values ('F', v_tdi, 'STKTEST1', 'Conductor de prueba', v_pais) returning persona_id into v_persona;
    insert into erp_stk_vehiculo (empresa_id, chapa, tipo, marca, capacidad, tara, persona_id_conductor)
    values (v_emp, 'ABC123', 'Camión', 'Marca', 8000, 3500, v_persona);

    -- Productos (por la API) y lotes
    select min(categoria_fiscal_id) into v_cafi from erp_gen_categoria_fiscal where codigo = 'GRAV10';
    select unidad_id into v_uni  from erp_stk_unidad where codigo = 'UNI';
    select unidad_id into v_kg   from erp_stk_unidad where codigo = 'KG';
    select unidad_id into v_caja from erp_stk_unidad where codigo = 'CAJA';
    crear_producto('P1',  'B', v_uni, 'N', 'N', 'N');
    crear_producto('P2',  'B', v_uni, 'S', 'N', 'S');
    erp_stk_lote_api.crear(i_producto_id => v_id, i_codigo => 'L1', i_fecha_vencimiento => trunc(current_date) + 365, o_lote_id => v_usuario);
    erp_stk_lote_api.crear(i_producto_id => v_id, i_codigo => 'LVENC', i_fecha_vencimiento => trunc(current_date) - 10, o_lote_id => v_usuario);
    crear_producto('P3',  'B', v_uni, 'N', 'S', 'N');
    crear_producto('PKG', 'B', v_kg,  'N', 'N', 'N');
    crear_producto('SRV', 'S', v_uni, 'N', 'N', 'N');

    -- Usuarios de prueba
    select rol_id into v_rol_adm from adm_seg_rol where codigo = 'ERP_ADMINISTRADOR';
    select rol_id into v_rol_usu from adm_seg_rol where codigo = 'ERP_USUARIO';
    crear_usuario('STK_QA_A', v_rol_adm, v_s1);
    crear_usuario('STK_QA_B', v_rol_adm, null);
    crear_usuario('STK_QA_C', v_rol_usu, null);
end;
/

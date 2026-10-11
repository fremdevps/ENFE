-- =============================================================================
-- Desinstalación ERP. No borra el registro en ADM (roles/permisos asignados a
-- usuarios) ni los mensajes de error; eso se gestiona desde la app ADM.
-- ATENCIÓN: borra las tablas del ERP y sus datos.
-- =============================================================================
declare
    procedure ejecutar (i_ddl in varchar2) is
    begin
        execute immediate i_ddl;
    exception
        when others then
            -- -942 tabla, -4043 objeto, -4080 trigger: ya no existe
            if sqlcode not in (-942, -4043, -4080) then raise; end if;
    end ejecutar;
begin
    -- Inventario (stk): primero, porque depende del módulo general
    for r in (select column_value nombre
                from table(sys.odcivarchar2list(
                         'erp_stk_traslado_api', 'erp_stk_lote_api', 'erp_stk_categoria_api',
                         'erp_stk_producto_api', 'erp_stk_movimiento_api', 'erp_stk_traslado_reg',
                         'erp_stk_producto_reg', 'erp_stk_movimiento_reg', 'erp_stk_traslado_evento_ctr',
                         'erp_stk_traslado_recep_det_ctr', 'erp_stk_traslado_recep_ctr', 'erp_stk_traslado_item_ctr',
                         'erp_stk_traslado_ctr', 'erp_stk_numerador_ctr', 'erp_stk_deposito_ubicacion_ctr',
                         'erp_stk_lote_ctr', 'erp_stk_producto_ctr', 'erp_stk_categoria_ctr',
                         'erp_stk_movimiento_item_ctr', 'erp_stk_movimiento_ctr', 'erp_stk_saldo_ctr',
                         'erp_stk_comun_utl'))) loop
        ejecutar('drop package ' || r.nombre);
    end loop;
    ejecutar('drop view erp_stk_traslado_transito_v');
    ejecutar('drop view erp_stk_saldo_producto_v');
    ejecutar('drop type erp_stk_tras_item_tab');
    ejecutar('drop type erp_stk_tras_item_typ');
    ejecutar('drop type erp_stk_mov_item_tab');
    ejecutar('drop type erp_stk_mov_item_typ');
    for r in (select column_value nombre
                from table(sys.odcivarchar2list(
                         'erp_stk_traslado_evento', 'erp_stk_traslado_recep_det', 'erp_stk_traslado_recep',
                         'erp_stk_traslado_item', 'erp_stk_traslado', 'erp_stk_ruta_traslado',
                         'erp_stk_motivo_traslado', 'erp_stk_numerador', 'erp_stk_saldo',
                         'erp_stk_movimiento_item', 'erp_stk_movimiento', 'erp_stk_tipo_movimiento',
                         'erp_stk_usuario_deposito', 'erp_stk_vehiculo', 'erp_stk_lote',
                         'erp_stk_kit', 'erp_stk_producto_proveedor', 'erp_stk_producto_deposito',
                         'erp_stk_producto_equiv', 'erp_stk_producto_unidad', 'erp_stk_producto_codigo',
                         'erp_stk_deposito_ubicacion', 'erp_stk_producto', 'erp_stk_marca',
                         'erp_stk_categoria', 'erp_stk_unidad'))) loop
        ejecutar('drop table ' || r.nombre || ' cascade constraints purge');
    end loop;

    for r in (select column_value nombre
                from table(sys.odcivarchar2list(
                         'erp_gen_funcionalidad_api', 'erp_gen_persona_api', 'erp_gen_periodo_api', 'erp_gen_impuesto_api',
                         'erp_gen_moneda_api', 'erp_gen_parametro_api', 'erp_gen_persona_reg', 'erp_gen_periodo_reg',
                         'erp_gen_impuesto_reg', 'erp_gen_moneda_reg', 'erp_gen_empresa_func_ctr', 'erp_gen_persona_ctr',
                         'erp_gen_periodo_ctr', 'erp_gen_parametro_ctr'))) loop
        ejecutar('drop package ' || r.nombre);
    end loop;

    ejecutar('drop view erp_gen_usuario_empresa_v');
    ejecutar('drop type erp_impuesto_calc_tab');
    ejecutar('drop type erp_impuesto_calc_typ');

    for r in (select column_value nombre
                from table(sys.odcivarchar2list(
                         'erp_gen_periodo_habilita', 'erp_gen_periodo', 'erp_gen_parametro', 'erp_gen_persona_rol',
                         'erp_gen_tipo_rol', 'erp_gen_persona_contacto', 'erp_gen_persona_direccion', 'erp_gen_persona_documento',
                         'erp_gen_persona', 'erp_gen_tipo_doc_identidad', 'erp_stk_deposito', 'erp_gen_usuario_sucursal',
                         'erp_gen_punto_expedicion', 'erp_gen_departamento', 'erp_gen_sucursal', 'erp_gen_empresa_func',
                         'erp_gen_empresa_config', 'erp_gen_rubro_func', 'erp_gen_rubro', 'erp_gen_funcionalidad',
                         'erp_gen_cotizacion', 'erp_gen_categoria_tasa', 'erp_gen_categoria_fiscal', 'erp_gen_impuesto_tasa_vig',
                         'erp_gen_impuesto_tasa', 'erp_gen_impuesto', 'erp_gen_ubicacion', 'erp_gen_feriado',
                         'erp_gen_pais', 'erp_gen_moneda'))) loop
        ejecutar('drop table ' || r.nombre || ' cascade constraints purge');
    end loop;
end;
/

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
    for r in (select column_value nombre
                from table(sys.odcivarchar2list(
                         'erp_gen_persona_api', 'erp_gen_periodo_api', 'erp_gen_impuesto_api', 'erp_gen_moneda_api',
                         'erp_gen_parametro_api', 'erp_gen_persona_reg', 'erp_gen_periodo_reg', 'erp_gen_impuesto_reg',
                         'erp_gen_moneda_reg', 'erp_gen_persona_ctr', 'erp_gen_periodo_ctr', 'erp_gen_parametro_ctr'))) loop
        ejecutar('drop package ' || r.nombre);
    end loop;

    ejecutar('drop view erp_gen_usuario_empresa_v');
    ejecutar('drop type erp_impuesto_calc_tab');
    ejecutar('drop type erp_impuesto_calc_typ');

    for r in (select column_value nombre
                from table(sys.odcivarchar2list(
                         'erp_gen_periodo', 'erp_gen_parametro', 'erp_gen_persona_contacto', 'erp_gen_persona_direccion',
                         'erp_gen_persona', 'erp_gen_tipo_doc_identidad', 'erp_gen_sucursal', 'erp_gen_empresa_config',
                         'erp_gen_cotizacion', 'erp_gen_categoria_tasa', 'erp_gen_categoria_fiscal', 'erp_gen_impuesto_tasa_vig',
                         'erp_gen_impuesto_tasa', 'erp_gen_impuesto', 'erp_gen_ubicacion', 'erp_gen_pais', 'erp_gen_moneda'))) loop
        ejecutar('drop table ' || r.nombre || ' cascade constraints purge');
    end loop;
end;
/

-- =============================================================================
-- Trigger : trg_adm_emp_aiud
-- Tabla   : adm_gen_empresa
-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).
--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):
--             @tools/db/generar_trigger_historial.sql adm_gen_empresa _ _ _
-- No auditadas: empresa_id (PK: va en registro_id) y las columnas de auditoría.
-- =============================================================================
create or replace trigger trg_adm_emp_aiud
    for insert or update or delete on adm_gen_empresa
    compound trigger

    v_cambios  adm_aud_cambio_api.t_cambios;

    after each row is
        v_detalle  json_array_t := json_array_t();
    begin
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'codigo',                         :old.codigo, :new.codigo);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'razon_social',                   :old.razon_social, :new.razon_social);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'nombre_comercial',               :old.nombre_comercial, :new.nombre_comercial);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'nro_documento',                  :old.nro_documento, :new.nro_documento);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'zona_horaria',                   :old.zona_horaria, :new.zona_horaria);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'estado',                         :old.estado, :new.estado);

        adm_aud_cambio_api.agregar(
            io_cambios          => v_cambios,
            i_app_codigo        => 'ADM',
            i_tabla             => 'ADM_GEN_EMPRESA',
            i_registro_id       => coalesce(:new.empresa_id, :old.empresa_id),
            i_registro_padre_id => null,
            i_empresa_id        => coalesce(:new.empresa_id, :old.empresa_id),
            i_operacion         => case when inserting then 'I' when updating then 'U' else 'D' end,
            i_detalle           => v_detalle);
    end after each row;

    after statement is
    begin
        adm_aud_cambio_api.registrar(io_cambios => v_cambios);
    end after statement;

end trg_adm_emp_aiud;
/

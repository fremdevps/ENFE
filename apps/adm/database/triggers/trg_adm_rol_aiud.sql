-- =============================================================================
-- Trigger : trg_adm_rol_aiud
-- Tabla   : adm_seg_rol
-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).
--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):
--             @tools/db/generar_trigger_historial.sql adm_seg_rol _ _ _
-- No auditadas: rol_id (PK: va en registro_id) y las columnas de auditoría.
-- =============================================================================
create or replace trigger trg_adm_rol_aiud
    for insert or update or delete on adm_seg_rol
    compound trigger

    v_cambios  adm_aud_cambio_api.t_cambios;

    after each row is
        v_detalle  json_array_t := json_array_t();
    begin
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'aplicacion_id',                  :old.aplicacion_id, :new.aplicacion_id);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'codigo',                         :old.codigo, :new.codigo);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'nombre',                         :old.nombre, :new.nombre);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'descripcion',                    :old.descripcion, :new.descripcion);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'es_superadmin',                  :old.es_superadmin, :new.es_superadmin);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'estado',                         :old.estado, :new.estado);

        adm_aud_cambio_api.agregar(
            io_cambios          => v_cambios,
            i_app_codigo        => 'ADM',
            i_tabla             => 'ADM_SEG_ROL',
            i_registro_id       => coalesce(:new.rol_id, :old.rol_id),
            i_registro_padre_id => null,
            i_empresa_id        => null,
            i_operacion         => case when inserting then 'I' when updating then 'U' else 'D' end,
            i_detalle           => v_detalle);
    end after each row;

    after statement is
    begin
        adm_aud_cambio_api.registrar(io_cambios => v_cambios);
    end after statement;

end trg_adm_rol_aiud;
/

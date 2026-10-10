-- =============================================================================
-- Trigger : trg_adm_rope_aiud
-- Tabla   : adm_seg_rol_permiso
-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).
--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):
--             @tools/db/generar_trigger_historial.sql adm_seg_rol_permiso rol_id _ _
-- No auditadas: rol_permiso_id (PK: va en registro_id) y las columnas de auditoría.
-- =============================================================================
create or replace trigger trg_adm_rope_aiud
    for insert or update or delete on adm_seg_rol_permiso
    compound trigger

    v_cambios  adm_aud_cambio_api.t_cambios;

    after each row is
        v_detalle  json_array_t := json_array_t();
    begin
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'rol_id',                         :old.rol_id, :new.rol_id);
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'permiso_id',                     :old.permiso_id, :new.permiso_id);

        adm_aud_cambio_api.agregar(
            io_cambios          => v_cambios,
            i_app_codigo        => 'ADM',
            i_tabla             => 'ADM_SEG_ROL_PERMISO',
            i_registro_id       => coalesce(:new.rol_permiso_id, :old.rol_permiso_id),
            i_registro_padre_id => coalesce(:new.rol_id, :old.rol_id),
            i_empresa_id        => null,
            i_operacion         => case when inserting then 'I' when updating then 'U' else 'D' end,
            i_detalle           => v_detalle);

        -- La tabla tiene una FK on delete cascade: cuando el cambio llega desde la tabla padre
        -- no se ejecuta "after statement", así que se inserta en el momento.
        if deleting then
            adm_aud_cambio_api.registrar(io_cambios => v_cambios);
        end if;
    end after each row;

    after statement is
    begin
        adm_aud_cambio_api.registrar(io_cambios => v_cambios);
    end after statement;

end trg_adm_rope_aiud;
/

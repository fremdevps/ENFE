-- =============================================================================
-- Trigger : trg_adm_usro_aiud
-- Tabla   : adm_seg_usuario_rol
-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).
--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):
--             @tools/db/generar_trigger_historial.sql adm_seg_usuario_rol usuario_id _ _
-- No auditadas: usuario_rol_id (PK: va en registro_id) y las columnas de auditoría.
-- =============================================================================
create or replace trigger trg_adm_usro_aiud
    for insert or update or delete on adm_seg_usuario_rol
    compound trigger

    v_cambios  adm_aud_cambio_api.t_cambios;

    after each row is
        v_detalle  json_array_t := json_array_t();
    begin
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'usuario_id',                     :old.usuario_id, :new.usuario_id);
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'rol_id',                         :old.rol_id, :new.rol_id);
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'empresa_id',                     :old.empresa_id, :new.empresa_id);
        adm_aud_cambio_utl.agregar_fecha(v_detalle,          'fecha_desde',                    :old.fecha_desde, :new.fecha_desde);
        adm_aud_cambio_utl.agregar_fecha(v_detalle,          'fecha_hasta',                    :old.fecha_hasta, :new.fecha_hasta);

        adm_aud_cambio_api.agregar(
            io_cambios          => v_cambios,
            i_app_codigo        => 'ADM',
            i_tabla             => 'ADM_SEG_USUARIO_ROL',
            i_registro_id       => coalesce(:new.usuario_rol_id, :old.usuario_rol_id),
            i_registro_padre_id => coalesce(:new.usuario_id, :old.usuario_id),
            i_empresa_id        => coalesce(:new.empresa_id, :old.empresa_id),
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

end trg_adm_usro_aiud;
/

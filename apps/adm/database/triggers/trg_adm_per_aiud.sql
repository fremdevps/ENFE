-- =============================================================================
-- Trigger : trg_adm_per_aiud
-- Tabla   : adm_seg_permiso
-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).
--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):
--             @tools/db/generar_trigger_historial.sql adm_seg_permiso modulo_id _ _
-- No auditadas: permiso_id (PK: va en registro_id) y las columnas de auditoría.
-- =============================================================================
create or replace trigger trg_adm_per_aiud
    for insert or update or delete on adm_seg_permiso
    compound trigger

    v_cambios  adm_aud_cambio_api.t_cambios;

    after each row is
        v_detalle  json_array_t := json_array_t();
    begin
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'modulo_id',                      :old.modulo_id, :new.modulo_id);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'codigo',                         :old.codigo, :new.codigo);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'nombre',                         :old.nombre, :new.nombre);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'descripcion',                    :old.descripcion, :new.descripcion);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'tipo',                           :old.tipo, :new.tipo);
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'apex_pagina_id',                 :old.apex_pagina_id, :new.apex_pagina_id);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'estado',                         :old.estado, :new.estado);

        adm_aud_cambio_api.agregar(
            io_cambios          => v_cambios,
            i_app_codigo        => 'ADM',
            i_tabla             => 'ADM_SEG_PERMISO',
            i_registro_id       => coalesce(:new.permiso_id, :old.permiso_id),
            i_registro_padre_id => coalesce(:new.modulo_id, :old.modulo_id),
            i_empresa_id        => null,
            i_operacion         => case when inserting then 'I' when updating then 'U' else 'D' end,
            i_detalle           => v_detalle);
    end after each row;

    after statement is
    begin
        adm_aud_cambio_api.registrar(io_cambios => v_cambios);
    end after statement;

end trg_adm_per_aiud;
/

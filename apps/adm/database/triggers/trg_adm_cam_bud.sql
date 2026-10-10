-- =============================================================================
-- Trigger : trg_adm_cam_bud
-- Tabla   : adm_aud_cambio
-- Desc    : Before Update/Delete (sentencia) - el historial es de solo inserción.
--           Rechaza todo update y todo delete que no sea la purga por retención
--           (adm_aud_cambio_api.purgar -> adm_aud_cambio_ctr.eliminar_anteriores).
-- =============================================================================
create or replace trigger trg_adm_cam_bud
    before update or delete on adm_aud_cambio
begin
    if updating or not adm_aud_cambio_ctr.es_purga_activa then
        raise_application_error(adm_aud_cambio_ctr.c_err_inmutable,
            'El historial de cambios no se puede modificar ni eliminar.');
    end if;
end trg_adm_cam_bud;
/

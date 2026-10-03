-- =============================================================================
-- Trigger : trg_adm_apl_bu
-- Tabla   : adm_seg_aplicacion
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_apl_bu
    before update on adm_seg_aplicacion
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_apl_bu;
/

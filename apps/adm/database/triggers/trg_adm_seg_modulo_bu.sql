-- =============================================================================
-- Trigger : trg_adm_seg_modulo_bu
-- Tabla   : adm_seg_modulo
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_seg_modulo_bu
    before update on adm_seg_modulo
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_seg_modulo_bu;
/

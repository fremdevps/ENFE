-- =============================================================================
-- Trigger : trg_erp_feco_bu
-- Tabla   : erp_doc_fe_config
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_feco_bu
    before update on erp_doc_fe_config
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_feco_bu;
/

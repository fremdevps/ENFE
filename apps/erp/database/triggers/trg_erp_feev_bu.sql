-- =============================================================================
-- Trigger : trg_erp_feev_bu
-- Tabla   : erp_doc_fe_evento
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_feev_bu
    before update on erp_doc_fe_evento
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_feev_bu;
/

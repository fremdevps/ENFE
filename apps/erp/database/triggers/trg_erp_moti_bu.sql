-- =============================================================================
-- Trigger : trg_erp_moti_bu
-- Tabla   : erp_doc_motivo
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_moti_bu
    before update on erp_doc_motivo
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_moti_bu;
/

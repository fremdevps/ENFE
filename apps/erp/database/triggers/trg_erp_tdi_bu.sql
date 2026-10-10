-- =============================================================================
-- Trigger : trg_erp_tdi_bu
-- Tabla   : erp_gen_tipo_doc_identidad
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_tdi_bu
    before update on erp_gen_tipo_doc_identidad
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_tdi_bu;
/

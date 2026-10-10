-- =============================================================================
-- Trigger : trg_erp_rufu_bu
-- Tabla   : erp_gen_rubro_func
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_rufu_bu
    before update on erp_gen_rubro_func
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_rufu_bu;
/

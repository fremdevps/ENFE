-- =============================================================================
-- Trigger : trg_erp_usdp_bu
-- Tabla   : erp_stk_usuario_deposito
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_usdp_bu
    before update on erp_stk_usuario_deposito
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_usdp_bu;
/

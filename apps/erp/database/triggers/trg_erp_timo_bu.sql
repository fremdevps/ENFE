-- =============================================================================
-- Trigger : trg_erp_timo_bu
-- Tabla   : erp_stk_tipo_movimiento
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_timo_bu
    before update on erp_stk_tipo_movimiento
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_timo_bu;
/

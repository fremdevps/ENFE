-- =============================================================================
-- Trigger : trg_erp_prun_bu
-- Tabla   : erp_stk_producto_unidad
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_prun_bu
    before update on erp_stk_producto_unidad
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_prun_bu;
/

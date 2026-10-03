-- =============================================================================
-- Trigger : trg_adm_mse_bu
-- Tabla   : adm_gen_mensaje_error
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_mse_bu
    before update on adm_gen_mensaje_error
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_mse_bu;
/

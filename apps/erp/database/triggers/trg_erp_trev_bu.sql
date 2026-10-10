-- =============================================================================
-- Trigger : trg_erp_trev_bu
-- Tabla   : erp_stk_traslado_evento
-- Desc    : Before Update - el historial es inmutable: no admite modificaciones.
-- =============================================================================
create or replace trigger trg_erp_trev_bu
    before update on erp_stk_traslado_evento
    for each row
begin
    raise_application_error(-20176, 'El historial del traslado no se puede modificar.');
end trg_erp_trev_bu;
/
